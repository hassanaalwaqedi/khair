import 'package:equatable/equatable.dart';

import '../../../../core/push/notification_target.dart';

/// Notification entity for user notifications
class AppNotification extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String notificationType;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.notificationType = 'general',
    this.data = const {},
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      notificationType: json['notification_type']?.toString() ?? 'general',
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      isRead: json['is_read'] == true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    String? notificationType,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      notificationType: notificationType ?? this.notificationType,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Human-readable time ago string
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  /// Route path for in-app notification taps. It shares the exact same typed
  /// mapping as system-notification taps, independent of localized copy.
  String get routePath => NotificationTarget.fromData({
        ...data,
        'type': data['type'] ?? notificationType,
        'notification_id': id,
      }).route;

  @override
  List<Object?> get props =>
      [id, userId, title, message, notificationType, data, isRead, createdAt];
}
