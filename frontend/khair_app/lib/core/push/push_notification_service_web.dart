import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../../features/notifications/domain/entities/notification_entity.dart';
import '../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../../features/notifications/presentation/notification_toast.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../router/app_router.dart' as router_lib;
import 'notification_target.dart';
import '../../firebase_options.dart';

const _vapidKey = String.fromEnvironment('FCM_WEB_VAPID_KEY');

Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  static PushNotificationService get instance => _instance;
  PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  bool _isAuthenticated = false;
  bool _activationInProgress = false;
  NotificationTarget? _pendingTarget;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);
      }
      if (!await _messaging.isSupported()) return;
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp
          .listen((message) => _queueNotificationTap(message.data));
      _messaging.onTokenRefresh.listen((token) {
        if (_isAuthenticated) unawaited(_registerToken(token));
      });
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _queueNotificationTap(initial.data);
    } catch (error) {
      debugPrint('[FCM:web] Initialization unavailable: $error');
    }
  }

  Future<bool> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission(
          alert: true, badge: true, sound: true);
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (granted) await _activateForAuthenticatedUser();
      return granted;
    } catch (error) {
      debugPrint('[FCM:web] Permission request failed: $error');
      return false;
    }
  }

  Future<void> onAuthenticationStateChanged(bool isAuthenticated) async {
    _isAuthenticated = isAuthenticated;
    if (!isAuthenticated) return;
    await _activateForAuthenticatedUser();
    _dispatchPendingTarget();
  }

  void clearSession() {
    _isAuthenticated = false;
    _pendingTarget = null;
  }

  void handleLocalNotificationTap(Map<String, dynamic> data) =>
      _queueNotificationTap(data);

  Future<void> removeToken() async {
    try {
      final token = await _messaging.getToken(
          vapidKey: _vapidKey.isEmpty ? null : _vapidKey);
      if (token != null && token.isNotEmpty) {
        await getIt<ApiClient>().delete('/devices', data: {'token': token});
      }
    } catch (error) {
      debugPrint('[FCM:web] Token removal failed: $error');
    }
  }

  Future<void> _activateForAuthenticatedUser() async {
    if (!_isAuthenticated || _activationInProgress) return;
    _activationInProgress = true;
    try {
      final settings = await _messaging.getNotificationSettings();
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) return;
      final token = await _messaging.getToken(vapidKey: _vapidKey);
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (error) {
      debugPrint('[FCM:web] Activation failed: $error');
    } finally {
      _activationInProgress = false;
    }
  }

  Future<void> _registerToken(String token) async {
    try {
      await getIt<ApiClient>()
          .post('/devices', data: {'token': token, 'platform': 'web'});
    } catch (error) {
      debugPrint('[FCM:web] Token registration failed: $error');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    final notification = AppNotification.fromJson({
      'id': data['notification_id'] ?? '',
      'title': message.notification?.title ?? data['title'] ?? '',
      'message': message.notification?.body ?? data['message'] ?? '',
      'notification_type': data['type'] ?? 'general',
      'data': data,
      'is_read': false,
      'created_at': DateTime.now().toIso8601String(),
    });
    getIt<NotificationBloc>().add(NotificationReceived(notification));
    NotificationToast.show(notification);
  }

  void _queueNotificationTap(Map<String, dynamic> data) {
    _pendingTarget = NotificationTarget.fromData(data);
    _dispatchPendingTarget();
  }

  void _dispatchPendingTarget() {
    if (!_isAuthenticated || _pendingTarget == null) return;
    final target = _pendingTarget!;
    _pendingTarget = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router_lib.appRouter.go(target.route);
      final id = target.notificationId;
      if (id != null && id.isNotEmpty) {
        getIt<NotificationBloc>().add(MarkNotificationRead(id));
      }
    });
  }
}
