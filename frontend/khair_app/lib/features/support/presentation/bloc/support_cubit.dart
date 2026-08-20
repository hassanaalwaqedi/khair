import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/websocket_service.dart';
import '../../data/models/support_model.dart';
import '../../data/support_repository.dart';

abstract class SupportState {
  const SupportState();
}

class SupportInitial extends SupportState {
  const SupportInitial();
}

class SupportLoading extends SupportState {
  const SupportLoading();
}

class SupportSessionActive extends SupportState {
  final SupportTicket ticket;
  final List<SupportMessage> messages;
  final bool isSending;
  final String? transientError;

  const SupportSessionActive(
    this.ticket,
    this.messages, {
    this.isSending = false,
    this.transientError,
  });

  SupportSessionActive copyWith({
    SupportTicket? ticket,
    List<SupportMessage>? messages,
    bool? isSending,
    String? transientError,
    bool clearError = false,
  }) =>
      SupportSessionActive(
        ticket ?? this.ticket,
        messages ?? this.messages,
        isSending: isSending ?? this.isSending,
        transientError:
            clearError ? null : (transientError ?? this.transientError),
      );
}

class SupportError extends SupportState {
  final String error;
  const SupportError(this.error);
}

class SupportCubit extends Cubit<SupportState> {
  final SupportRepository _repository;
  StreamSubscription? _wsSubscription;

  SupportCubit(this._repository) : super(const SupportInitial()) {
    _wsSubscription =
        WebSocketService.instance.messages.listen(_onWebSocketMessage);
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    return super.close();
  }

  Future<void> openConversation(
    String language, {
    String? initialTicketId,
    String? contextType,
    String? contextId,
  }) async {
    emit(const SupportLoading());
    try {
      if (initialTicketId != null && initialTicketId.isNotEmpty) {
        final tickets = await _repository.getUserTickets();
        final matchingTicket =
            tickets.where((ticket) => ticket.id == initialTicketId);
        if (matchingTicket.isNotEmpty) {
          final ticket = matchingTicket.first;
          final messages = await _repository.getMessages(ticket.id);
          emit(SupportSessionActive(ticket, messages));
          return;
        }
      }
      final conversation = await _repository.openConversation(
        language: language,
        contextType: contextType,
        contextId: contextId,
      );
      emit(SupportSessionActive(conversation.ticket, conversation.messages));
    } catch (_) {
      emit(const SupportError('support_unavailable'));
    }
  }

  Future<void> loadTicket(SupportTicket ticket) async {
    emit(const SupportLoading());
    try {
      final messages = await _repository.getMessages(ticket.id);
      emit(SupportSessionActive(ticket, messages));
    } catch (_) {
      emit(const SupportError('support_unavailable'));
    }
  }

  Future<List<SupportTicket>> getHistory() => _repository.getUserTickets();

  Future<void> sendMessage(String text) async {
    final current = state;
    final body = text.trim();
    if (current is! SupportSessionActive || body.isEmpty || current.isSending) {
      return;
    }

    final optimistic = SupportMessage(
      id: 'pending_${DateTime.now().microsecondsSinceEpoch}',
      ticketId: current.ticket.id,
      senderType: 'user',
      body: body,
      createdAt: DateTime.now(),
      isPending: true,
    );
    emit(current.copyWith(
      messages: [...current.messages, optimistic],
      isSending: true,
      clearError: true,
    ));

    try {
      final persisted = await _repository.sendMessage(current.ticket.id, body);
      final updated = _mergeMessages(
        current.messages.where((message) => message.id != optimistic.id),
        persisted,
      );
      emit(SupportSessionActive(current.ticket, updated));
    } catch (_) {
      final failed = optimistic.copyWith(isPending: false, isFailed: true);
      emit(SupportSessionActive(
        current.ticket,
        [...current.messages, failed],
        transientError: 'message_failed',
      ));
    }
  }

  Future<void> retryMessage(SupportMessage failedMessage) async {
    final current = state;
    if (current is! SupportSessionActive || !failedMessage.isFailed) return;
    emit(current.copyWith(
      messages: current.messages
          .where((message) => message.id != failedMessage.id)
          .toList(),
      clearError: true,
    ));
    await sendMessage(failedMessage.body);
  }

  Future<void> uploadAttachment(Uint8List bytes, String filename) async {
    final current = state;
    if (current is! SupportSessionActive || current.isSending) return;
    emit(current.copyWith(isSending: true, clearError: true));
    try {
      final message = await _repository.uploadAttachment(
          current.ticket.id, bytes, filename);
      emit(SupportSessionActive(
        current.ticket,
        _mergeMessages(current.messages, [message]),
      ));
    } catch (_) {
      emit(current.copyWith(
        isSending: false,
        transientError: 'attachment_failed',
      ));
    }
  }

  Future<void> escalate() async {
    final current = state;
    if (current is! SupportSessionActive || !current.ticket.isAiActive) return;
    emit(current.copyWith(isSending: true, clearError: true));
    try {
      await _repository.escalateConversation(current.ticket.id);
      // Escalation is durable on the POST. A best-effort refresh must not
      // revert the user back to AI mode when older history cannot be read.
      var messages = current.messages;
      try {
        final refreshed = await _repository.getMessages(current.ticket.id);
        if (refreshed.isNotEmpty) messages = refreshed;
      } catch (_) {
        // Keep the visible conversation and show the waiting-for-support
        // state. The server has already accepted the handoff.
      }
      emit(SupportSessionActive(
        current.ticket.copyWith(status: 'waiting_for_agent'),
        messages,
      ));
    } catch (_) {
      emit(current.copyWith(
          isSending: false, transientError: 'escalation_failed'));
    }
  }

  Future<void> resolve() async {
    final current = state;
    if (current is! SupportSessionActive || current.ticket.isResolved) return;
    emit(current.copyWith(isSending: true, clearError: true));
    try {
      await _repository.resolveConversation(current.ticket.id);
      final messages = await _repository.getMessages(current.ticket.id);
      emit(SupportSessionActive(
        current.ticket.copyWith(status: 'resolved'),
        messages,
      ));
    } catch (_) {
      emit(current.copyWith(
          isSending: false, transientError: 'resolution_failed'));
    }
  }

  void _onWebSocketMessage(Map<String, dynamic> message) {
    final current = state;
    if (current is! SupportSessionActive) return;
    final type = message['type']?.toString();
    final data = message['data'];
    if (data is! Map) return;
    final payload = Map<String, dynamic>.from(data);

    if (type == 'support.message_created') {
      final incoming = SupportMessage.fromJson(payload);
      if (incoming.ticketId != current.ticket.id) return;
      emit(current.copyWith(
          messages: _mergeMessages(current.messages, [incoming])));
      return;
    }
    if (type == 'support.ticket_assigned' || type == 'support.ticket_updated') {
      final incoming = SupportTicket.fromJson(payload);
      if (incoming.id == current.ticket.id) {
        emit(current.copyWith(ticket: incoming));
      }
    }
  }

  List<SupportMessage> _mergeMessages(
    Iterable<SupportMessage> current,
    Iterable<SupportMessage> incoming,
  ) {
    final byID = <String, SupportMessage>{
      for (final message in current) message.id: message,
      for (final message in incoming) message.id: message,
    };
    final messages = byID.values.toList()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return messages;
  }
}
