class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  Future<void> init() async {}

  void setOnNotificationTap(
      void Function(Map<String, dynamic> data) callback) {}

  Future<void> showNotification({
    String? title,
    String? body,
    required Map<String, dynamic> data,
  }) async {}
}
