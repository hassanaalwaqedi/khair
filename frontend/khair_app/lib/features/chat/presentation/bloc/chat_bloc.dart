import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/datasources/chat_datasource.dart';
import '../../domain/entities/lesson_request.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/chat_message.dart';

// ══════════════════════════════════════════
//  EVENTS
// ══════════════════════════════════════════

abstract class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

class LoadConversations extends ChatEvent {
  const LoadConversations();
}

class LoadMessages extends ChatEvent {
  final String conversationId;
  const LoadMessages(this.conversationId);
  @override
  List<Object?> get props => [conversationId];
}

class SendMessage extends ChatEvent {
  final String conversationId;
  final String message;
  const SendMessage(this.conversationId, this.message);
  @override
  List<Object?> get props => [conversationId, message];
}

class PollMessages extends ChatEvent {
  final String conversationId;
  const PollMessages(this.conversationId);
  @override
  List<Object?> get props => [conversationId];
}

class CreateLessonRequest extends ChatEvent {
  final String sheikhId;
  final String message;
  final String? preferredTime;
  const CreateLessonRequest({
    required this.sheikhId,
    required this.message,
    this.preferredTime,
  });
  @override
  List<Object?> get props => [sheikhId, message, preferredTime];
}

class LoadMyLessonRequests extends ChatEvent {
  const LoadMyLessonRequests();
}

class LoadSheikhLessonRequests extends ChatEvent {
  const LoadSheikhLessonRequests();
}

class RespondToLessonRequest extends ChatEvent {
  final String requestId;
  final String status;
  const RespondToLessonRequest(this.requestId, this.status);
  @override
  List<Object?> get props => [requestId, status];
}

class MarkMessagesAsRead extends ChatEvent {
  final String conversationId;
  const MarkMessagesAsRead(this.conversationId);
  @override
  List<Object?> get props => [conversationId];
}

// ══════════════════════════════════════════
//  STATE
// ══════════════════════════════════════════

enum ChatStatus { initial, loading, success, failure }

class ChatState extends Equatable {
  final ChatStatus conversationsStatus;
  final ChatStatus messagesStatus;
  final ChatStatus requestsStatus;
  final List<Conversation> conversations;
  final List<ChatMessage> messages;
  final List<LessonRequest> lessonRequests;
  final String? activeConversationId;
  final String? errorMessage;

  const ChatState({
    this.conversationsStatus = ChatStatus.initial,
    this.messagesStatus = ChatStatus.initial,
    this.requestsStatus = ChatStatus.initial,
    this.conversations = const [],
    this.messages = const [],
    this.lessonRequests = const [],
    this.activeConversationId,
    this.errorMessage,
  });

  ChatState copyWith({
    ChatStatus? conversationsStatus,
    ChatStatus? messagesStatus,
    ChatStatus? requestsStatus,
    List<Conversation>? conversations,
    List<ChatMessage>? messages,
    List<LessonRequest>? lessonRequests,
    String? activeConversationId,
    String? errorMessage,
  }) {
    return ChatState(
      conversationsStatus: conversationsStatus ?? this.conversationsStatus,
      messagesStatus: messagesStatus ?? this.messagesStatus,
      requestsStatus: requestsStatus ?? this.requestsStatus,
      conversations: conversations ?? this.conversations,
      messages: messages ?? this.messages,
      lessonRequests: lessonRequests ?? this.lessonRequests,
      activeConversationId: activeConversationId ?? this.activeConversationId,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        conversationsStatus, messagesStatus, requestsStatus,
        conversations, messages, lessonRequests,
        activeConversationId, errorMessage,
      ];
}

// ══════════════════════════════════════════
//  BLOC
// ══════════════════════════════════════════

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatDatasource _datasource;
  Timer? _pollTimer;

  ChatBloc(this._datasource) : super(const ChatState()) {
    on<LoadConversations>(_onLoadConversations);
    on<LoadMessages>(_onLoadMessages);
    on<SendMessage>(_onSendMessage);
    on<PollMessages>(_onPollMessages);
    on<CreateLessonRequest>(_onCreateLessonRequest);
    on<LoadMyLessonRequests>(_onLoadMyRequests);
    on<LoadSheikhLessonRequests>(_onLoadSheikhRequests);
    on<RespondToLessonRequest>(_onRespondToRequest);
    on<MarkMessagesAsRead>(_onMarkAsRead);
  }

  Future<void> _onLoadConversations(LoadConversations event, Emitter<ChatState> emit) async {
    emit(state.copyWith(conversationsStatus: ChatStatus.loading));
    try {
      final convs = await _datasource.getConversations();
      emit(state.copyWith(conversationsStatus: ChatStatus.success, conversations: convs));
    } catch (e) {
      emit(state.copyWith(conversationsStatus: ChatStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMessages(LoadMessages event, Emitter<ChatState> emit) async {
    emit(state.copyWith(messagesStatus: ChatStatus.loading, activeConversationId: event.conversationId));
    try {
      final msgs = await _datasource.getMessages(event.conversationId);
      emit(state.copyWith(messagesStatus: ChatStatus.success, messages: msgs));
      // Start polling
      _startPolling(event.conversationId);
      // Mark as read
      add(MarkMessagesAsRead(event.conversationId));
    } catch (e) {
      emit(state.copyWith(messagesStatus: ChatStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onSendMessage(SendMessage event, Emitter<ChatState> emit) async {
    try {
      final msg = await _datasource.sendMessage(event.conversationId, event.message);
      emit(state.copyWith(messages: [...state.messages, msg]));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onPollMessages(PollMessages event, Emitter<ChatState> emit) async {
    if (state.activeConversationId != event.conversationId) return;
    try {
      final msgs = await _datasource.getMessages(event.conversationId);
      if (msgs.length != state.messages.length) {
        emit(state.copyWith(messages: msgs));
      }
    } catch (_) {}
  }

  Future<void> _onMarkAsRead(MarkMessagesAsRead event, Emitter<ChatState> emit) async {
    try {
      await _datasource.markAsRead(event.conversationId);
    } catch (_) {}
  }

  Future<void> _onCreateLessonRequest(CreateLessonRequest event, Emitter<ChatState> emit) async {
    emit(state.copyWith(requestsStatus: ChatStatus.loading));
    try {
      await _datasource.createLessonRequest(
        sheikhId: event.sheikhId,
        message: event.message,
        preferredTime: event.preferredTime,
      );
      emit(state.copyWith(requestsStatus: ChatStatus.success));
    } catch (e) {
      emit(state.copyWith(requestsStatus: ChatStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMyRequests(LoadMyLessonRequests event, Emitter<ChatState> emit) async {
    emit(state.copyWith(requestsStatus: ChatStatus.loading));
    try {
      final reqs = await _datasource.getMyLessonRequests();
      emit(state.copyWith(requestsStatus: ChatStatus.success, lessonRequests: reqs));
    } catch (e) {
      emit(state.copyWith(requestsStatus: ChatStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadSheikhRequests(LoadSheikhLessonRequests event, Emitter<ChatState> emit) async {
    emit(state.copyWith(requestsStatus: ChatStatus.loading));
    try {
      final reqs = await _datasource.getSheikhLessonRequests();
      emit(state.copyWith(requestsStatus: ChatStatus.success, lessonRequests: reqs));
    } catch (e) {
      emit(state.copyWith(requestsStatus: ChatStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onRespondToRequest(RespondToLessonRequest event, Emitter<ChatState> emit) async {
    try {
      await _datasource.respondToRequest(event.requestId, event.status);
      // Refresh the list
      final reqs = await _datasource.getSheikhLessonRequests();
      emit(state.copyWith(lessonRequests: reqs));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  void _startPolling(String conversationId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      add(PollMessages(conversationId));
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
