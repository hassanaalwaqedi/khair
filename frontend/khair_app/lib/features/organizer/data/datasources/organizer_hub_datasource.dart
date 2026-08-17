import '../../../../core/network/api_client.dart';

/// API boundary for the self-scoped Organizer Hub. No client-side statistics
/// are derived here: all totals and comparisons come from the server aggregate.
class OrganizerHubDataSource {
  OrganizerHubDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getDashboard({
    String range = '30d',
    DateTime? start,
    DateTime? end,
  }) async {
    final response = await _apiClient.get(
      '/organizer/dashboard',
      queryParameters: {
        'range': range,
        if (start != null) 'start': start.toUtc().toIso8601String(),
        if (end != null) 'end': end.toUtc().toIso8601String(),
      },
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<void> sendAnnouncement({
    required String eventId,
    required String title,
    required String message,
    required String type,
  }) async {
    await _apiClient.post('/events/$eventId/notify-attendees', data: {
      'title': title,
      'message': message,
      'type': type,
      'include_link': false,
    });
  }

  Future<List<Map<String, dynamic>>> getAttendees({
    required String organizationId,
    required String eventId,
  }) async {
    final response = await _apiClient.get(
      '/org/$organizationId/events/$eventId/attendees',
      queryParameters: const {'page_size': 100, 'status': 'confirmed'},
    );
    final data = response.data['data'] as Map<String, dynamic>? ?? {};
    final raw = data['attendees'] as List<dynamic>? ?? const [];
    return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }
}
