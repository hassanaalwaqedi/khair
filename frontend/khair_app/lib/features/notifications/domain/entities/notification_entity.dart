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
      case 'event_join_confirmed':
      case 'event_joined':
      case 'event_reminder':
      case 'event_updated':
      case 'event_cancelled':
      case 'event_participant_joined':
      case 'organizer_announcement':
      case 'organizer_message':
      case 'new_participant':
        final eventId = data['event_id'];
        return eventId == null ? '/my-events' : '/events/$eventId';
      default:
        return null;
    }
  }

  @override
  List<Object?> get props =>
      [id, userId, title, message, notificationType, data, isRead, createdAt];
}
