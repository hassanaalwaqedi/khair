import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/core/network/api_client.dart';
import 'package:khair_app/features/support/data/models/support_model.dart';
import 'package:khair_app/features/support/data/support_repository.dart';
import 'package:khair_app/features/support/presentation/bloc/support_cubit.dart';

class _SupportRepository extends SupportRepository {
  _SupportRepository(this.conversation) : super(ApiClient(Dio()));

  final SupportConversation conversation;

  @override
  Future<SupportConversation> openConversation({
    required String language,
    String? contextType,
    String? contextId,
  }) async =>
      conversation;

  @override
  Future<List<SupportTicket>> getUserTickets() async => [conversation.ticket];

  @override
  Future<List<SupportMessage>> getMessages(String ticketId) async =>
      conversation.messages;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final ticket = SupportTicket(
    id: 't1',
    userId: 'u1',
    category: 'general',
    subject: 'Khair support conversation',
    status: 'ai_active',
    language: 'en',
    createdAt: DateTime(2026, 8, 20),
  );
  final welcome = SupportMessage(
    id: 'm1',
    ticketId: ticket.id,
    senderType: 'ai',
    body: 'Hello from Khair AI',
    createdAt: DateTime(2026, 8, 20),
  );

  group('SupportCubit', () {
    late SupportCubit cubit;

    setUp(() {
      cubit = SupportCubit(
        _SupportRepository(
          SupportConversation(
              ticket: ticket, messages: [welcome], created: true),
        ),
      );
    });

    tearDown(() => cubit.close());

    test('initial state is SupportInitial', () {
      expect(cubit.state, isA<SupportInitial>());
    });

    test('opens a persisted AI conversation without a ticket form', () async {
      await cubit.openConversation('en');

      final state = cubit.state as SupportSessionActive;
      expect(state.ticket.id, ticket.id);
      expect(state.ticket.isAiActive, isTrue);
      expect(state.messages.single.body, 'Hello from Khair AI');
    });
  });
}
