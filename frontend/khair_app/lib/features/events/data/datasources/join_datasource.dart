import '../../../../core/network/api_client.dart';

/// Data source for join-register and reservation API endpoints
class JoinDataSource {
  final ApiClient _apiClient;

  JoinDataSource(this._apiClient);

  /// Step 1: Name + Email
  Future<Map<String, dynamic>> submitStep1({
    required String name,
    required String email,
    String? eventId,
  }) async {
    final response = await _apiClient.post('/join-register/step1', data: {
      'name': name,
      'email': email,
      if (eventId != null) 'event_id': eventId,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Step 2: Password + Gender + Age
  Future<Map<String, dynamic>> submitStep2({
    required String draftId,
    required String password,
    required String gender,
    int? age,
  }) async {
    final response = await _apiClient.post('/join-register/step2', data: {
      'draft_id': draftId,
      'password': password,
      'gender': gender,
      if (age != null) 'age': age,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Verify email token
  Future<Map<String, dynamic>> verifyEmail(String token) async {
    final response = await _apiClient.post('/join-register/verify', data: {
      'token': token,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Reserve a seat at an event
  Future<Map<String, dynamic>> joinEvent(String eventId) async {
    final response = await _apiClient.post('/events/$eventId/join');
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Cancel reservation
  Future<void> cancelReservation(String eventId) async {
    await _apiClient.delete('/events/$eventId/join');
  }

  /// Check event availability (public)
  Future<Map<String, dynamic>> getAvailability(String eventId) async {
    final response = await _apiClient.get('/events/$eventId/availability');
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Check user's registration status for an event
  Future<Map<String, dynamic>> getRegistrationStatus(String eventId) async {
    final response = await _apiClient.get('/events/$eventId/registration-status');
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Get user's reservations
  Future<List<dynamic>> getMyReservations() async {
    final response = await _apiClient.get('/my/reservations');
    return response.data['data'] as List<dynamic>;
  }
}
