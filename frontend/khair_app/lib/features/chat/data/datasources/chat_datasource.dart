
import '../../../../core/network/api_client.dart';
import '../../domain/entities/lesson_request.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/chat_message.dart';

class ChatDatasource {
  final ApiClient _api;

  ChatDatasource(this._api);

  // ── Lesson Requests ──

  Future<LessonRequest> createLessonRequest({
    required String sheikhId,
    required String message,
    String? preferredTime,
  }) async {
    final res = await _api.post('/lesson-requests', data: {
      'sheikh_id': sheikhId,
      'message': message,
      if (preferredTime != null) 'preferred_time': preferredTime,
    });
    return LessonRequest.fromJson(res.data['data']);
  }

  Future<List<LessonRequest>> getMyLessonRequests() async {
    final res = await _api.get('/my/lesson-requests');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((j) => LessonRequest.fromJson(j)).toList();
  }

  Future<List<LessonRequest>> getSheikhLessonRequests() async {
    final res = await _api.get('/sheikh/lesson-requests');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((j) => LessonRequest.fromJson(j)).toList();
  }

  Future<LessonRequest> respondToRequest(String requestId, String status) async {
    final res = await _api.post('/lesson-requests/$requestId/respond', data: {
      'status': status,
    });
    return LessonRequest.fromJson(res.data['data']);
  }

  // ── Conversations ──

  Future<List<Conversation>> getConversations() async {
    final res = await _api.get('/conversations');
    final list = (res.data['data'] as List?) ?? [];
    return list.map((j) => Conversation.fromJson(j)).toList();
  }

  // ── Messages ──

  Future<List<ChatMessage>> getMessages(String conversationId, {int page = 1, int pageSize = 50}) async {
    final res = await _api.get(
      '/conversations/$conversationId/messages',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    final list = (res.data['data'] as List?) ?? [];
    return list.map((j) => ChatMessage.fromJson(j)).toList();
  }

  Future<ChatMessage> sendMessage(String conversationId, String message) async {
    final res = await _api.post('/conversations/$conversationId/messages', data: {
      'message': message,
    });
    return ChatMessage.fromJson(res.data['data']);
  }

  Future<void> markAsRead(String conversationId) async {
    await _api.post('/conversations/$conversationId/read');
  }
}
