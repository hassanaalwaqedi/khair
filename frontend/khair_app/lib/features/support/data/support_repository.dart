import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import 'models/support_model.dart';

class SupportRepository {
  final ApiClient _apiClient;

  SupportRepository(this._apiClient);

  Future<Map<String, dynamic>> startSession(
      String category, String subject) async {
    final response = await _apiClient.post('/support/sessions',
        data: {'category': category, 'subject': subject});
    return {
      'ticket': SupportTicket.fromJson(response.data['ticket']),
      'message': SupportMessage.fromJson(response.data['message']),
    };
  }

  Future<List<SupportTicket>> getUserTickets() async {
    final response = await _apiClient.get('/support/tickets');
    final List list = response.data['tickets'] ?? [];
    return list.map((e) => SupportTicket.fromJson(e)).toList();
  }

  Future<List<SupportMessage>> getMessages(String ticketId) async {
    final response =
        await _apiClient.get('/support/tickets/$ticketId/messages');
    final List list = response.data['messages'] ?? [];
    return list.map((e) => SupportMessage.fromJson(e)).toList();
  }

  Future<SupportMessage> sendMessage(String ticketId, String body) async {
    final response = await _apiClient
        .post('/support/tickets/$ticketId/messages', data: {'body': body});
    return SupportMessage.fromJson(response.data['message']);
  }

  Future<void> escalateTicket(String ticketId) async {
    await _apiClient.post('/support/tickets/$ticketId/escalate');
  }

  Future<void> resolveTicket(String ticketId) async {
    await _apiClient.post('/support/tickets/$ticketId/resolve');
  }

  Future<SupportMessage> uploadAttachment(
    String ticketId,
    Uint8List bytes,
    String filename,
  ) async {
    final formData = FormData.fromMap({
      'attachment': MultipartFile.fromBytes(bytes, filename: filename),
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
    return SupportMessage.fromJson(response.data['message']);
  }
}
