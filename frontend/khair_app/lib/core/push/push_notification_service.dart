import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/notifications/presentation/bloc/notification_bloc.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../router/app_router.dart' as router_lib;
import 'local_notification_service.dart';
import 'notification_target.dart';

const _permissionPromptedKey = 'push_permission_prompted_v1';

/// Required by Firebase for data/background handling in release builds. It is
/// intentionally UI-free: Android renders notification payloads in the system
/// tray while background navigation is deferred until the user taps.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

/// Handles FCM setup, authenticated token lifecycle, and safe notification
/// navigation. Firebase listeners are installed once per process; the token is
/// registered only after an authenticated session has permission to receive it.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  static PushNotificationService get instance => _instance;
  PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  bool _initialized = false;
  bool _isAuthenticated = false;
  bool _activationInProgress = false;
  NotificationTarget? _pendingTarget;

  /// Installs message listeners and captures cold-start notification taps. It
  /// does not prompt for permission or register with the backend yet.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _queueNotificationTap(message.data),
    );
    _messaging.onTokenRefresh.listen((token) {
      if (_isAuthenticated) {
        unawaited(_registerTokenWithBackend(token));
      }
    });

    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _queueNotificationTap(initialMessage.data);
      }
    } catch (error) {
      debugPrint('[FCM] Unable to read initial notification: $error');
    }
  }

  /// Called after every resolved auth-state transition. It is safe to call more
  /// than once: listeners are not duplicated and Android's permission prompt is
  /// requested at most once by Khair.
  Future<void> onAuthenticationStateChanged(bool isAuthenticated) async {
    _isAuthenticated = isAuthenticated;
    if (!isAuthenticated) return;

    await _activateForAuthenticatedUser();
    _dispatchPendingTarget();
  }

  /// Called before a manual logout clears the authenticated API session.
  void clearSession() {
    _isAuthenticated = false;
    _pendingTarget = null;
  }

  /// Receives a foreground local-notification tap from the local notification
  /// service. It follows the same typed, auth-safe path as an FCM tray tap.
  void handleLocalNotificationTap(Map<String, dynamic> data) {
    _queueNotificationTap(data);
  }

  Future<void> _activateForAuthenticatedUser() async {
    if (_activationInProgress) return;
    _activationInProgress = true;
    try {
      if (!await _hasNotificationPermission()) return;
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerTokenWithBackend(token);
      }
    } catch (error) {
      debugPrint('[FCM] Activation failed: $error');
    } finally {
      _activationInProgress = false;
    }
  }

  Future<bool> _hasNotificationPermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.notification.status;
      if (status.isGranted || status.isLimited) return true;
      if (status.isPermanentlyDenied || status.isRestricted) return false;

      final preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(_permissionPromptedKey) ?? false) return false;
      await preferences.setBool(_permissionPromptedKey, true);
      status = await Permission.notification.request();
      return status.isGranted || status.isLimited;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    getIt<NotificationBloc>().add(const LoadUnreadCount());
    // FCM does not show notification payloads while Flutter is foregrounded,
    // so exactly one local notification provides the equivalent OS feedback.
    if (message.notification == null) return;
    await LocalNotificationService.instance.showNotification(
      title: message.notification?.title,
      body: message.notification?.body,
      data: Map<String, dynamic>.from(message.data),
    );
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
      try {
        router_lib.appRouter.go(target.route);
        final notificationId = target.notificationId;
        if (notificationId != null && notificationId.isNotEmpty) {
          getIt<NotificationBloc>().add(MarkNotificationRead(notificationId));
        }
      } catch (error) {
        debugPrint('[FCM] Notification navigation failed: $error');
      }
    });
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      await getIt<ApiClient>().post('/devices', data: {
        'token': token,
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
      debugPrint('[FCM] Device token registered');
    } catch (error) {
      debugPrint('[FCM] Device token registration failed: $error');
    }
  }

  /// Deactivates the current device registration while the API token is still
  /// valid. Failure is non-fatal because the next login safely reassigns the
  /// unique physical token to the authenticated account.
  Future<void> removeToken() async {
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await getIt<ApiClient>().delete('/devices', data: {'token': token});
      debugPrint('[FCM] Device token deactivated');
    } catch (error) {
      debugPrint('[FCM] Device token deactivation failed: $error');
    }
  }
}
