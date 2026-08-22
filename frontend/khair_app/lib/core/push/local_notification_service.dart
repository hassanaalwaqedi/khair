import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android channel IDs are a backend contract. Do not rename existing IDs:
/// Android users control channel settings after the first install.
class KhairNotificationChannels {
  static const important = 'khair_important';
  static const messages = 'khair_messages';
  static const reminders = 'khair_reminders';
  static const updates = 'khair_updates';
  static const general = 'khair_general';

  static String forData(Map<String, dynamic> data) {
    switch (data['type']?.toString()) {
      case 'event_reminder':
        return reminders;
      case 'event_cancelled':
      case 'organizer_approved':
      case 'organizer_rejected':
      case 'organizer_revision_requested':
      case 'event_approved':
      case 'event_rejected':
      case 'event_revision_requested':
      case 'verification_review':
      case 'account_suspended':
        return important;
      // Support replies must arrive as heads-up notifications — use the HIGH
      // importance messages channel so Android shows the banner with sound.
      case 'support_reply':
      case 'support_attachment':
      case 'support_message':
        return messages;
      case 'event_join_confirmed':
      case 'event_participant_joined':
      case 'event_updated':
      case 'organizer_announcement':
        return updates;
      default:
        return general;
    }
  }
}

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  void Function(Map<String, dynamic> data)? _onNotificationTap;
  Map<String, dynamic>? _launchPayload;
  bool _initialized = false;

  /// Set after the router/auth lifecycle is ready. A launch payload is queued
  /// until this callback exists so no cold-start navigation is lost.
  void setOnNotificationTap(void Function(Map<String, dynamic> data) callback) {
    _onNotificationTap = callback;
    final launchPayload = _launchPayload;
    if (launchPayload != null) {
      _launchPayload = null;
      callback(launchPayload);
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android:
          AndroidInitializationSettings('@drawable/ic_stat_khair_notification'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) =>
          _handlePayload(response.payload),
    );

    await _createAndroidChannels();
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp ?? false) {
      _handlePayload(launchDetails?.notificationResponse?.payload);
    }
    _initialized = true;
  }

  Future<void> _createAndroidChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    const channels = [
      AndroidNotificationChannel(
        KhairNotificationChannels.important,
        'Important Khair updates',
        description:
            'Approvals, cancellations, and actions that need attention.',
        importance: Importance.high,
      ),
      // HIGH importance so support replies show as heads-up notifications
      // with sound and vibration per the user's device settings.
      AndroidNotificationChannel(
        KhairNotificationChannels.messages,
        'Messages',
        description: 'Support messages and replies from Khair.',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      ),
      AndroidNotificationChannel(
        KhairNotificationChannels.reminders,
        'Event reminders',
        description: 'Reminders for events you registered for.',
        importance: Importance.high,
      ),
      AndroidNotificationChannel(
        KhairNotificationChannels.updates,
        'Event and account updates',
        description: 'Event activity and account updates from Khair.',
        importance: Importance.defaultImportance,
      ),
      AndroidNotificationChannel(
        KhairNotificationChannels.general,
        'Khair notifications',
        description: 'General Khair notifications.',
        importance: Importance.defaultImportance,
      ),
    ];
    for (final channel in channels) {
      await android.createNotificationChannel(channel);
    }
  }

  Future<void> showNotification({
    String? title,
    String? body,
    required Map<String, dynamic> data,
  }) async {
    final channelId = KhairNotificationChannels.forData(data);
    final channel = _channelDetails(channelId);
    final notificationId = data['notification_id']?.toString().hashCode ??
        DateTime.now().microsecondsSinceEpoch.remainder(1 << 31);
    await _plugin.show(
      id: notificationId,
      title: title ?? 'Khair',
      body: body ?? '',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: 'ic_stat_khair_notification',
          importance: channel.importance,
          priority: channel.priority,
          visibility: NotificationVisibility.private,
        ),
        iOS: const DarwinNotificationDetails(sound: 'default'),
      ),
      payload: jsonEncode(data),
    );
  }

  _ChannelDetails _channelDetails(String channelId) {
    switch (channelId) {
      case KhairNotificationChannels.important:
        return const _ChannelDetails(
          id: KhairNotificationChannels.important,
          name: 'Important Khair updates',
          description:
              'Approvals, cancellations, and actions that need attention.',
          importance: Importance.high,
          priority: Priority.high,
        );
      case KhairNotificationChannels.messages:
        return const _ChannelDetails(
          id: KhairNotificationChannels.messages,
          name: 'Messages',
          description: 'Support messages and replies from Khair.',
          importance: Importance.high,
          priority: Priority.high,
        );
      case KhairNotificationChannels.reminders:
        return const _ChannelDetails(
          id: KhairNotificationChannels.reminders,
          name: 'Event reminders',
          description: 'Reminders for events you registered for.',
          importance: Importance.high,
          priority: Priority.high,
        );
      case KhairNotificationChannels.updates:
        return const _ChannelDetails(
          id: KhairNotificationChannels.updates,
          name: 'Event and account updates',
          description: 'Event activity and account updates from Khair.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );
      default:
        return const _ChannelDetails(
          id: KhairNotificationChannels.general,
          name: 'Khair notifications',
          description: 'General Khair notifications.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        );
    }
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      final callback = _onNotificationTap;
      if (callback == null) {
        _launchPayload = data;
        return;
      }
      callback(data);
    } catch (_) {
      // Ignore malformed local payloads. FCM data is always handled separately.
    }
  }
}

class _ChannelDetails {
  const _ChannelDetails({
    required this.id,
    required this.name,
    required this.description,
    required this.importance,
    required this.priority,
  });

  final String id;
  final String name;
  final String description;
  final Importance importance;
  final Priority priority;
}
