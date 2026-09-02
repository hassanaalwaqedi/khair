import 'dart:developer' as dev;

import '../../../../core/network/api_client.dart';
import '../../domain/entities/notification_entity.dart';

/// Remote data source for notification API calls
class NotificationRemoteDataSource {
  final ApiClient _apiClient;

  NotificationRemoteDataSource(this._apiClient);

  /// Fetch all notifications for the authenticated user
  Future<List<AppNotification>> getNotifications() async {
    final response = await _apiClient.get('/notifications');
    dev.log('[NotificationDS] GET /notifications → ${response.statusCode}');
    final responseData = response.data;
    dev.log('[NotificationDS] response type: ${responseData.runtimeType}');

    // Handle both wrapped {success: true, data: [...]} and direct list responses
    List<dynamic> list;
    if (responseData is Map && responseData.containsKey('data')) {
      final data = responseData['data'];
      if (data is List) {
        list = data;
      } else {
        dev.log('[NotificationDS] "data" is ${data.runtimeType}: $data');
        list = [];
      }
    } else if (responseData is List) {
      list = responseData;
    } else {
      dev.log('[NotificationDS] Unexpected format: $responseData');
      list = [];
    }

    dev.log('[NotificationDS] Raw list count: ${list.length}');
    if (list.isNotEmpty) {
      dev.log(
          '[NotificationDS] First item keys: ${list.first is Map ? (list.first as Map).keys.toList() : "NOT A MAP"}');
    }

    final notifications = <AppNotification>[];
    for (int i = 0; i < list.length; i++) {
      try {
        notifications.add(AppNotification.fromJson(
          Map<String, dynamic>.from(list[i] as Map),
        ));
      } catch (e, st) {
        dev.log('[NotificationDS] Parse error [$i]: $e\njson: ${list[i]}\n$st');
      }
    }
    dev.log(
        '[NotificationDS] Parsed ${notifications.length}/${list.length} notifications');
    return notifications;
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

  Future<void> deleteNotification(String id) async {
    await _apiClient.delete('/notifications/$id');
  }
}
