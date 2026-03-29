import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'local_notification_service.dart';

import '../di/injection.dart';
import '../network/api_client.dart';
import '../router/app_router.dart' as router_lib;

/// Handles FCM push notification setup, token management, and message handling.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  static PushNotificationService get instance => _instance;
  PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initialize push notifications: request permission, get token, listen for refresh.
  Future<void> initialize() async {
    // 1. Request permission (required on iOS, Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Android 13+ notification permission
    if (Platform.isAndroid) {
      var status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] User denied notification permission');
      return;
    }

    debugPrint('[FCM] Permission granted: ${settings.authorizationStatus}');

    // 2. Get FCM token
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Token: ${token.substring(0, 20)}...');
        await _registerTokenWithBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
    }

    // 3. Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed');
      _registerTokenWithBackend(newToken);
    });

    // 4. Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('[FCM] Foreground message: ${message.notification?.title}');
      // Show local notification with route payload
      await LocalNotificationService.instance.showNotification(
        title: message.notification?.title,
        body: message.notification?.body,
        payload: _buildRouteFromData(message.data),
      );
    });

    // 5. Handle background/terminated message taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Message opened app: ${message.data}');
      _handleNotificationTap(message.data);
    });

    // 6. Check if app was opened from a terminated state notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM] App opened from terminated state: ${initialMessage.data}');
      _handleNotificationTap(initialMessage.data);
    }
  }

  /// Navigate to the appropriate screen based on notification data. 
  void _handleNotificationTap(Map<String, dynamic> data) {
    final route = _buildRouteFromData(data);
    if (route != null) {
      try {
        router_lib.appRouter.go(route);
      } catch (e) {
        debugPrint('[FCM] Navigation error: $e');
      }
    }
  }

  /// Build a route path from notification data payload.
  String? _buildRouteFromData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'chat_message':
        final convId = data['conversation_id'];
        if (convId != null) return '/conversations/$convId';
        return '/conversations';
      case 'lesson_request':
        return '/sheikh-dashboard';
      case 'lesson_response':
        return '/conversations';
      case 'lesson_scheduled':
        return '/conversations';
      default:
        return null;
    }
  }

  /// Register the FCM token with the backend.
  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final apiClient = getIt<ApiClient>();
      final platform = kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android');
      await apiClient.post('/devices', data: {
        'token': token,
        'platform': platform,
      });
      debugPrint('[FCM] Token registered with backend');
    } catch (e) {
      debugPrint('[FCM] Error registering token: $e');
    }
  }

  /// Remove the FCM token from the backend (call on logout).
  Future<void> removeToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        final apiClient = getIt<ApiClient>();
        await apiClient.delete('/devices/$token');
        debugPrint('[FCM] Token removed from backend');
      }
    } catch (e) {
      debugPrint('[FCM] Error removing token: $e');
    }
  }
}
