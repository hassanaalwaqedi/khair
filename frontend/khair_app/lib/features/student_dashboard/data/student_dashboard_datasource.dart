import '../../../core/network/api_client.dart';

/// Data source for student dashboard API calls.
class StudentDashboardDatasource {
  final ApiClient _api;

  StudentDashboardDatasource(this._api);

  /// Get student's bookings (all statuses).
  Future<List<Map<String, dynamic>>> getMyBookings() async {
    final res = await _api.get('/my/bookings');
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Get student's lesson requests.
  Future<List<Map<String, dynamic>>> getMyLessonRequests() async {
    final res = await _api.get('/my/lesson-requests');
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Get sheikhs the student has interacted with.
  Future<List<Map<String, dynamic>>> getMySheikhs() async {
    final res = await _api.get('/student/sheikhs');
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  /// Get aggregated learning stats.
  Future<Map<String, dynamic>> getMyStats() async {
    final res = await _api.get('/student/stats');
    return res.data['data'] as Map<String, dynamic>;
  }

  /// Cancel a booking.
  Future<void> cancelBooking(String bookingId) async {
    await _api.post('/bookings/$bookingId/cancel');
  }

  /// Submit a review for a sheikh.
  Future<void> submitReview({
    required String sheikhId,
    required int rating,
    String? comment,
    String? lessonRequestId,
  }) async {
    await _api.post('/sheikhs/$sheikhId/review', data: {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
      if (lessonRequestId != null) 'lesson_request_id': lessonRequestId,
    });
  }
}
