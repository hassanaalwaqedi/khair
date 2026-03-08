import '../../../../core/network/api_client.dart';
import '../../domain/entities/notification_entity.dart';

/// Remote data source for notification API calls
class NotificationRemoteDataSource {
  final ApiClient _apiClient;

  NotificationRemoteDataSource(this._apiClient);

  /// Fetch all notifications for the authenticated user
  Future<List<AppNotification>> getNotifications() async {
    final response = await _apiClient.get('/notifications');
    final List<dynamic> list = response.data['data'] ?? [];
    return list.map((json) => AppNotification.fromJson(json)).toList();
  }

  /// Get the count of unread notifications
  Future<int> getUnreadCount() async {
    final response = await _apiClient.get('/notifications/unread-count');
    return response.data['data']?['unread_count'] ?? 0;
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String id) async {
    await _apiClient.put('/notifications/$id/read');
  }

  /// Mark all notifications as read
  Future<void> markAllRead() async {
    await _apiClient.put('/notifications/read-all');
  }
}
