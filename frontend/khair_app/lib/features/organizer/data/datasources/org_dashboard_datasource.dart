import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

/// API client for organization dashboard endpoints.
/// Uses the shared [ApiClient] (Dio-based) for consistent auth/interceptor handling.
class OrgDashboardDatasource {
  final ApiClient _client;

  OrgDashboardDatasource(this._client);

  // ── Dashboard ──

  Future<Map<String, dynamic>> getDashboard(String orgId) async {
    final res = await _client.get('/org/$orgId/dashboard');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnalytics(String orgId) async {
    final res = await _client.get('/org/$orgId/analytics');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getActivity(String orgId, {int limit = 20}) async {
    final res = await _client.get('/org/$orgId/activity', queryParameters: {'limit': limit});
    return res.data as Map<String, dynamic>;
  }

  // ── Events ──

  Future<Map<String, dynamic>> listEvents(String orgId, {int page = 1, int pageSize = 20, String? status}) async {
    final params = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (status != null) params['status'] = status;
    final res = await _client.get('/org/$orgId/events', queryParameters: params);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createEvent(String orgId, Map<String, dynamic> eventData) async {
    final res = await _client.post('/org/$orgId/events', data: eventData);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEvent(String orgId, String eventId, Map<String, dynamic> updates) async {
    final res = await _client.put('/org/$orgId/events/$eventId', data: updates);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> cancelEvent(String orgId, String eventId) async {
    final res = await _client.delete('/org/$orgId/events/$eventId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> duplicateEvent(String orgId, String eventId) async {
    final res = await _client.post('/org/$orgId/events/$eventId/duplicate');
    return res.data as Map<String, dynamic>;
  }

  // ── Attendees ──

  Future<Map<String, dynamic>> listAttendees(String orgId, String eventId,
      {int page = 1, int pageSize = 20, String? search, String? status}) async {
    final params = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (search != null) params['search'] = search;
    if (status != null) params['status'] = status;
    final res = await _client.get('/org/$orgId/events/$eventId/attendees', queryParameters: params);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> markAttendance(String orgId, String eventId, String regId, bool attended) async {
    final res = await _client.put(
      '/org/$orgId/events/$eventId/attendees/$regId/attendance',
      data: {'attended': attended},
    );
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> removeAttendee(String orgId, String eventId, String regId) async {
    final res = await _client.delete('/org/$orgId/events/$eventId/attendees/$regId');
    return res.data as Map<String, dynamic>;
  }

  Future<String> exportAttendeesCSV(String orgId, String eventId) async {
    final dio = Dio(); // Use raw Dio for CSV download (different content type)
    final res = await dio.get<String>(
      '/org/$orgId/events/$eventId/attendees/export',
      options: Options(responseType: ResponseType.plain),
    );
    return res.data ?? '';
  }

  // ── Profile ──

  Future<Map<String, dynamic>> getProfile(String orgId) async {
    final res = await _client.get('/org/$orgId/profile');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateProfile(String orgId, Map<String, dynamic> data) async {
    final res = await _client.put('/org/$orgId/profile', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Members ──

  Future<Map<String, dynamic>> listMembers(String orgId) async {
    final res = await _client.get('/org/$orgId/members');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addMember(String orgId, String email, String role) async {
    final res = await _client.post('/org/$orgId/members', data: {'email': email, 'role': role});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMemberRole(String orgId, String memberId, String role) async {
    final res = await _client.put('/org/$orgId/members/$memberId', data: {'role': role});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> removeMember(String orgId, String memberId) async {
    final res = await _client.delete('/org/$orgId/members/$memberId');
    return res.data as Map<String, dynamic>;
  }
}
