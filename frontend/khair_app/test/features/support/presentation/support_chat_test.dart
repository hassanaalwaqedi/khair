import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:khair_app/features/support/presentation/pages/support_chat_page.dart';
import 'package:khair_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:khair_app/features/support/data/models/support_model.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// Create a mock SupportCubit
class MockSupportCubit extends Mock implements SupportCubit {
  @override
  Stream<SupportState> get stream => const Stream.empty();
}

void main() {
  group('SupportChatPage', () {
    testWidgets('renders Start Session when in SupportInitial', (WidgetTester tester) async {
      final mockCubit = MockSupportCubit();
      when(mockCubit.state).thenReturn(SupportInitial());
      
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<SupportCubit>.value(
            value: mockCubit,
            child: const SupportChatPage(),
          ),
        ),
      );

      expect(find.text('How can we help you?'), findsOneWidget);
      expect(find.text('Start Chat'), findsOneWidget);
    });

    testWidgets('renders Chat Bubbles when in SupportSessionActive', (WidgetTester tester) async {
      final mockCubit = MockSupportCubit();
      final ticket = SupportTicket(id: '1', userId: 'u1', category: 'Gen', subject: 'Help', status: 'ai_active', createdAt: DateTime.now());
      final msg = SupportMessage(id: 'm1', ticketId: '1', senderType: 'ai', body: 'AI Reply', createdAt: DateTime.now());
      
      when(mockCubit.state).thenReturn(SupportSessionActive(ticket, [msg]));
      
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<SupportCubit>.value(
            value: mockCubit,
            child: const SupportChatPage(),
          ),
        ),
      );

      expect(find.text('You are chatting with Khair AI'), findsOneWidget);
      expect(find.text('AI Reply'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
