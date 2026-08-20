import 'package:firebase_messaging/firebase_messaging.dart';

/// Web is intentionally out of scope for Khair's native system-tray flow.
/// Keep this facade API-compatible so auth/session code remains platform-safe.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  static PushNotificationService get instance => _instance;
  PushNotificationService._();

  Future<void> initialize() async {}

  Future<void> removeToken() async {}

  Future<void> onAuthenticationStateChanged(bool isAuthenticated) async {}

  void clearSession() {}

  void handleLocalNotificationTap(Map<String, dynamic> data) {}
}
