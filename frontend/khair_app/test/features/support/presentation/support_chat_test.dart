import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/core/network/api_client.dart';
import 'package:khair_app/features/support/data/models/support_model.dart';
import 'package:khair_app/features/support/data/support_repository.dart';
import 'package:khair_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:khair_app/features/support/presentation/pages/support_chat_page.dart';

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
  testWidgets('opens a messenger immediately without the old support form',
      (WidgetTester tester) async {
    final ticket = SupportTicket(
      id: '1',
      userId: 'u1',
      category: 'general',
      subject: 'Support conversation',
      status: 'ai_active',
      language: 'en',
      createdAt: DateTime.now(),
    );
    final message = SupportMessage(
      id: 'm1',
      ticketId: ticket.id,
      senderType: 'ai',
      body: 'AI Reply',
      createdAt: DateTime.now(),
    );
    final cubit = SupportCubit(_SupportRepository(
      SupportConversation(ticket: ticket, messages: [message], created: true),
    ));
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const SupportChatPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Khair Support'), findsOneWidget);
    expect(find.text('AI Reply'), findsOneWidget);
    expect(find.text('Start Chat'), findsNothing);
    expect(find.text('How can we help you?'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
  });
}
