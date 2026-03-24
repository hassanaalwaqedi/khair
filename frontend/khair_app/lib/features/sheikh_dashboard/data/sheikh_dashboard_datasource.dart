import '../../../core/network/api_client.dart';
import '../../chat/domain/entities/lesson_request.dart';

/// Data source for sheikh dashboard API calls.
class SheikhDashboardDatasource {
  final ApiClient _apiClient;

  SheikhDashboardDatasource(this._apiClient);

  /// Fetch all lesson requests for the logged-in sheikh.
  Future<List<LessonRequest>> getLessonRequests() async {
    final response = await _apiClient.get('/sheikh/lesson-requests');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => LessonRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Accept or reject a lesson request.
  Future<LessonRequest> respondToRequest(String requestId, String status) async {
    final response = await _apiClient.post(
      '/lesson-requests/$requestId/respond',
      data: {'status': status},
    );
    return LessonRequest.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Schedule a lesson with meeting details.
  Future<void> scheduleLesson({
    required String requestId,
    required String meetingLink,
    required String meetingPlatform,
    required String scheduledTime,
  }) async {
    await _apiClient.post(
      '/lesson-requests/$requestId/schedule',
      data: {
        'meeting_link': meetingLink,
        'meeting_platform': meetingPlatform,
        'scheduled_time': scheduledTime,
      },
    );
  }
}
