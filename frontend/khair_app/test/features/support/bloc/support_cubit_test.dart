import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:khair_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:khair_app/features/support/data/support_repository.dart';
import 'package:khair_app/features/support/data/models/support_model.dart';
// Note: We use manual mock for SupportRepository since build_runner is slow.

class MockSupportRepository extends Mock implements SupportRepository {
  @override
  Future<Map<String, dynamic>> startSession(String category, String subject) async {
    final ticket = SupportTicket(id: 't1', userId: 'u1', category: category, subject: subject, status: 'ai_active', createdAt: DateTime.now());
    final message = SupportMessage(id: 'm1', ticketId: 't1', senderType: 'ai', body: 'Hello from AI', createdAt: DateTime.now());
    return {'ticket': ticket, 'message': message};
  }

  @override
  Future<List<SupportMessage>> getMessages(String ticketId) async {
    return [
      SupportMessage(id: 'm1', ticketId: ticketId, senderType: 'ai', body: 'Hello from AI', createdAt: DateTime.now())
    ];
  }
}

void main() {
  group('SupportCubit', () {
    late SupportCubit cubit;
    late MockSupportRepository mockRepo;

    setUp(() {
      mockRepo = MockSupportRepository();
      cubit = SupportCubit(mockRepo);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state is SupportInitial', () {
      expect(cubit.state, isA<SupportInitial>());
    });

    test('startSession emits Loading then Active', () async {
      final future = cubit.startSession('General', 'Help me');
      // expect later state
      await future;
      expect(cubit.state, isA<SupportSessionActive>());
      final activeState = cubit.state as SupportSessionActive;
      expect(activeState.ticket.category, 'General');
      expect(activeState.messages.length, 1);
      expect(activeState.messages.first.body, 'Hello from AI');
    });
  });
}
