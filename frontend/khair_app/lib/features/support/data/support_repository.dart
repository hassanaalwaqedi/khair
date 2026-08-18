import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import 'models/support_model.dart';

class SupportRepository {
  final ApiClient _apiClient;

  SupportRepository(this._apiClient);

  Future<Map<String, dynamic>> startSession(String category, String subject) async {
    final response = await _apiClient.post('/support/sessions', data: {'category': category, 'subject': subject});
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
    final response = await _apiClient.get('/support/tickets/$ticketId/messages');
    final List list = response.data['messages'] ?? [];
    return list.map((e) => SupportMessage.fromJson(e)).toList();
  }

  Future<SupportMessage> sendMessage(String ticketId, String body) async {
    final response = await _apiClient.post('/support/tickets/$ticketId/messages', data: {'body': body});
    return SupportMessage.fromJson(response.data['message']);
  }

  Future<void> escalateTicket(String ticketId) async {
    await _apiClient.post('/support/tickets/$ticketId/escalate');
  }

  Future<void> resolveTicket(String ticketId) async {
    await _apiClient.post('/support/tickets/$ticketId/resolve');
  }

  Future<SupportMessage> uploadAttachment(String ticketId, String filePath) async {
    final formData = FormData.fromMap({
      'attachment': await MultipartFile.fromFile(filePath),
    });
    final response = await _apiClient.post('/support/tickets/$ticketId/attachments', data: formData);
    return SupportMessage.fromJson(response.data['message']);
  }
}
