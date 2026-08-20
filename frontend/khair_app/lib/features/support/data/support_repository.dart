import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'models/support_model.dart';

class SupportRepository {
  final ApiClient _apiClient;

  SupportRepository(this._apiClient);

  Future<SupportConversation> openConversation({
    required String language,
    String? contextType,
    String? contextId,
  }) async {
    final response = await _apiClient.post(
      '/support/conversations',
      data: {
        'language': language,
        if (contextType != null && contextId != null)
          'context_type': contextType,
        if (contextType != null && contextId != null) 'context_id': contextId,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final rawMessages = (data['messages'] as List? ?? const []);
    return SupportConversation(
      ticket: SupportTicket.fromJson(
        Map<String, dynamic>.from(data['conversation'] ?? data['ticket']),
      ),
      messages: rawMessages
          .whereType<Map>()
          .map((item) =>
              SupportMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      created: data['created'] == true,
    );
  }

  // Kept for backwards compatibility with old deep links and support clients.
  Future<SupportConversation> startSession(
      String category, String subject) async {
    final response = await _apiClient.post(
      '/support/sessions',
      data: {'category': category, 'subject': subject},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final ticket =
        SupportTicket.fromJson(Map<String, dynamic>.from(data['ticket']));
    final messages = await getMessages(ticket.id);
    return SupportConversation(
        ticket: ticket, messages: messages, created: true);
  }

  Future<List<SupportTicket>> getUserTickets() async {
    final response = await _apiClient.get('/support/tickets');
    final List list = response.data['tickets'] ?? [];
    return list
        .whereType<Map>()
        .map((item) => SupportTicket.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<SupportMessage>> getMessages(String ticketId) async {
    final response =
        await _apiClient.get('/support/tickets/$ticketId/messages');
    final List list = response.data['messages'] ?? [];
    return list
        .whereType<Map>()
        .map((item) => SupportMessage.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<SupportMessage>> sendMessage(String ticketId, String body) async {
    final response = await _apiClient.post(
      '/support/tickets/$ticketId/messages',
      data: {'body': body, 'message_type': 'text'},
    );
    final rawMessages = response.data['messages'] as List?;
    if (rawMessages != null) {
      return rawMessages
          .whereType<Map>()
          .map((item) =>
              SupportMessage.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }
    return [
      SupportMessage.fromJson(
          Map<String, dynamic>.from(response.data['message'])),
    ];
  }

  Future<void> escalateConversation(String ticketId) async {
    await _apiClient.post('/support/tickets/$ticketId/escalate');
  }

  Future<void> resolveConversation(String ticketId) async {
    await _apiClient.post('/support/tickets/$ticketId/resolve');
  }

  Future<SupportMessage> uploadAttachment(
    String ticketId,
    Uint8List bytes,
    String filename,
  ) async {
    final formData = FormData.fromMap({
      'attachment': MultipartFile.fromBytes(
        bytes,
        filename: filename,
        // The API deliberately rejects generic octet-stream uploads. Send a
        // concrete image type so its server-side image allow-list protects the
        // same request on mobile and web.
        contentType: _imageMediaType(filename),
      ),
    });
    final response = await _apiClient.post(
      '/support/tickets/$ticketId/attachments',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    return SupportMessage.fromJson(
        Map<String, dynamic>.from(response.data['message']));
  }

  DioMediaType _imageMediaType(String filename) {
    switch (filename.split('.').last.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return DioMediaType('image', 'jpeg');
      case 'png':
        return DioMediaType('image', 'png');
      case 'webp':
        return DioMediaType('image', 'webp');
      default:
        // The page validates this before upload; keep the request explicit if
        // another caller bypasses that UI.
        return DioMediaType('application', 'octet-stream');
    }
  }
}
