import 'package:dio/dio.dart';

import '../../../core/di/injection.dart';
import '../../../core/network/api_client.dart';

/// Admin-only API for the organizer trust review queue. Media and documents are
/// requested through audited, short-lived URLs; their storage paths are never
/// exposed to the Flutter client.
class OrganizerApplicationAdminApi {
  OrganizerApplicationAdminApi({ApiClient? client})
      : _client = client ?? getIt<ApiClient>();

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> list({String? status}) async {
    final response = await _client.get(
      '/admin/organizer-applications',
      queryParameters:
          status == null || status.isEmpty ? null : {'status': status},
    );
    final data = response.data['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<Map<String, dynamic>> detail(String id) async {
    final response = await _client.get('/admin/organizer-applications/$id');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> decide({
    required String id,
    required String decision,
    String reasonCode = '',
    String userMessage = '',
    String internalNote = '',
  }) async {
    final path = switch (decision) {
      'approved' => 'approve',
      'needs_revision' => 'request-changes',
      'rejected' => 'reject',
      _ => throw ArgumentError.value(decision, 'decision'),
    };
    final response = await _client.post(
      '/admin/organizer-applications/$id/$path',
      data: {
        'reason_code': reasonCode,
        'user_message': userMessage,
        'internal_note': internalNote,
      },
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Uri> documentUrl(String applicationId, String fileId) async {
    final response = await _client.post(
      '/admin/organizer-applications/$applicationId/documents/$fileId/access',
    );
    return Uri.parse((response.data['data'] as Map)['url'] as String);
  }

  Future<Uri> mediaUrl(String applicationId, String kind) async {
    final response = await _client.post(
      '/admin/organizer-applications/$applicationId/media/$kind/access',
    );
    return Uri.parse((response.data['data'] as Map)['url'] as String);
  }

  static String errorMessage(Object error,
      {String fallback = 'Action failed.'}) {
    if (error is DioException && error.response?.data is Map) {
      final data = error.response!.data as Map;
      final message = data['message'] ?? data['error'];
      if (message is String && message.isNotEmpty) return message;
    }
    return fallback;
  }
}
