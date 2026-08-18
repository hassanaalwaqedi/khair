import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/models/support_model.dart';
import '../../data/support_repository.dart';
import '../../../../core/services/websocket_service.dart';

abstract class SupportState {}

class SupportInitial extends SupportState {}
class SupportLoading extends SupportState {}
class SupportSessionActive extends SupportState {
  final SupportTicket ticket;
  final List<SupportMessage> messages;
  final bool isLoading;

  SupportSessionActive(this.ticket, this.messages, {this.isLoading = false});
}
class SupportError extends SupportState {
  final String error;
  SupportError(this.error);
}

class SupportCubit extends Cubit<SupportState> {
  final SupportRepository _repository;
  StreamSubscription? _wsSubscription;

  SupportCubit(this._repository) : super(SupportInitial()) {
    _wsSubscription = WebSocketService.instance.messages.listen((msg) {
      if (msg['event'] == 'support.message_created') {
        final payload = msg['payload'];
        if (payload != null) {
          onNewMessage(SupportMessage.fromJson(payload));
        }
      } else if (msg['event'] == 'support.ticket_assigned' || msg['event'] == 'support.ticket_updated') {
        final payload = msg['payload'];
        if (payload != null) {
          _updateTicket(SupportTicket.fromJson(payload));
        }
      }
    });
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    return super.close();
  }

  Future<void> startSession(String category, String subject) async {
    emit(SupportLoading());
    try {
      final res = await _repository.startSession(category, subject);
      final ticket = res['ticket'] as SupportTicket;
      final msg = res['message'] as SupportMessage;
      
      // Initially, we have user's subject as first message (implied) and AI's msg
      // Let's fetch all immediately to have a consistent state
      final msgs = await _repository.getMessages(ticket.id);
      
      emit(SupportSessionActive(ticket, msgs));
    } catch (e) {
      emit(SupportError(e.toString()));
    }
  }

  Future<void> loadTicket(SupportTicket ticket) async {
    emit(SupportLoading());
    try {
      final msgs = await _repository.getMessages(ticket.id);
      emit(SupportSessionActive(ticket, msgs));
    } catch (e) {
      emit(SupportError(e.toString()));
    }
  }

  Future<void> sendMessage(String text) async {
    final currentState = state;
    if (currentState is! SupportSessionActive) return;

    final ticket = currentState.ticket;
    final currentMsgs = List<SupportMessage>.from(currentState.messages);
    
    // Optimistic UI update
    final optimisticMsg = SupportMessage(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      ticketId: ticket.id,
      senderType: 'user',
      body: text,
      createdAt: DateTime.now(),
    );
    currentMsgs.add(optimisticMsg);
    emit(SupportSessionActive(ticket, currentMsgs, isLoading: true));

    try {
      final actualMsg = await _repository.sendMessage(ticket.id, text);
      // Replace optimistic message
      currentMsgs.removeLast();
      currentMsgs.add(actualMsg);
      emit(SupportSessionActive(ticket, currentMsgs, isLoading: false));
    } catch (e) {
      // Revert on failure
      currentMsgs.removeLast();
      emit(SupportSessionActive(ticket, currentMsgs, isLoading: false));
      // could show toast here
    }
  }

  Future<void> uploadAttachment(String filePath) async {
    final currentState = state;
    if (currentState is! SupportSessionActive) return;

    final ticket = currentState.ticket;
    emit(SupportSessionActive(ticket, currentState.messages, isLoading: true));

    try {
      final actualMsg = await _repository.uploadAttachment(ticket.id, filePath);
      final currentMsgs = List<SupportMessage>.from(currentState.messages);
      currentMsgs.add(actualMsg);
      emit(SupportSessionActive(ticket, currentMsgs, isLoading: false));
    } catch (e) {
      emit(SupportSessionActive(ticket, currentState.messages, isLoading: false));
    }
  }

  Future<void> escalate() async {
    final currentState = state;
    if (currentState is! SupportSessionActive) return;

    emit(SupportSessionActive(currentState.ticket, currentState.messages, isLoading: true));
    try {
      await _repository.escalateTicket(currentState.ticket.id);
      // Refresh messages to get system message
      final msgs = await _repository.getMessages(currentState.ticket.id);
      // Update ticket status locally
      final updatedTicket = SupportTicket(
        id: currentState.ticket.id,
        userId: currentState.ticket.userId,
        category: currentState.ticket.category,
        subject: currentState.ticket.subject,
        status: 'waiting_for_support',
        createdAt: currentState.ticket.createdAt,
      );
      emit(SupportSessionActive(updatedTicket, msgs, isLoading: false));
    } catch (e) {
      emit(SupportSessionActive(currentState.ticket, currentState.messages, isLoading: false));
    }
  }

  Future<void> resolve() async {
    final currentState = state;
    if (currentState is! SupportSessionActive) return;

    emit(SupportSessionActive(currentState.ticket, currentState.messages, isLoading: true));
    try {
      await _repository.resolveTicket(currentState.ticket.id);
      // Refresh messages
      final msgs = await _repository.getMessages(currentState.ticket.id);
      final updatedTicket = SupportTicket(
        id: currentState.ticket.id,
        userId: currentState.ticket.userId,
        category: currentState.ticket.category,
        subject: currentState.ticket.subject,
        status: 'resolved',
        createdAt: currentState.ticket.createdAt,
      );
      emit(SupportSessionActive(updatedTicket, msgs, isLoading: false));
    } catch (e) {
      emit(SupportSessionActive(currentState.ticket, currentState.messages, isLoading: false));
    }
  }

  // Handle incoming websocket messages
  void onNewMessage(SupportMessage msg) {
    final currentState = state;
    if (currentState is! SupportSessionActive) return;

    if (currentState.ticket.id == msg.ticketId) {
      final currentMsgs = List<SupportMessage>.from(currentState.messages);
      currentMsgs.add(msg);
      emit(SupportSessionActive(currentState.ticket, currentMsgs, isLoading: currentState.isLoading));
    }
  }

  void _updateTicket(SupportTicket ticket) {
    final currentState = state;
    if (currentState is! SupportSessionActive) return;

    if (currentState.ticket.id == ticket.id) {
      emit(SupportSessionActive(ticket, currentState.messages, isLoading: currentState.isLoading));
    }
  }
}
