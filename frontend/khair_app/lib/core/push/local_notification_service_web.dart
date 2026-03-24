/// Stub implementation for web – local notifications are not supported on web.
class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  Future<void> init() async {
    // No-op on web
  }

  Future<void> showNotification({String? title, String? body}) async {
    // No-op on web
  }
}
