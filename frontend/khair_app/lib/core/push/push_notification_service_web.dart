/// Stub implementation for web – push notifications are not supported on web.
class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._();
  static PushNotificationService get instance => _instance;
  PushNotificationService._();

  Future<void> initialize() async {
    // No-op on web
  }

  Future<void> removeToken() async {
    // No-op on web
  }
}
