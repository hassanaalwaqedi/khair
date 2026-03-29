import 'package:equatable/equatable.dart';

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
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      message: json['message'],
      notificationType: json['notification_type'] ?? 'general',
      data: (json['data'] as Map<String, dynamic>?) ?? {},
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
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

  /// Route path for deep-linking on notification tap
  String? get routePath {
    switch (notificationType) {
      case 'chat_message':
        final convId = data['conversation_id'];
        if (convId != null) return '/conversations/$convId';
        return '/conversations';
      case 'lesson_request':
        return '/sheikh-dashboard';
      case 'lesson_response':
        return '/conversations';
      case 'lesson_scheduled':
        final convId = data['conversation_id'];
        if (convId != null) return '/conversations/$convId';
        return '/conversations';
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [id, userId, title, message, notificationType, data, isRead, createdAt];
}
