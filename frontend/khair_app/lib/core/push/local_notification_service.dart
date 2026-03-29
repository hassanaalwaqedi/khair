import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  void Function(String route)? _onNotificationTap;

  /// Set a callback to navigate when a notification is tapped.
  void setOnNotificationTap(void Function(String route) callback) {
    _onNotificationTap = callback;
  }

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Navigate on notification tap
        if (response.payload != null && response.payload!.isNotEmpty) {
          _onNotificationTap?.call(response.payload!);
        }
      },
    );
    // Create high importance channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'khair_high', // id
      'Khair Notifications', // name
      description: 'High importance notifications for Khair app',
      importance: Importance.max,
      playSound: true,
    );
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> showNotification({String? title, String? body, String? payload}) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'khair_high',
      'Khair Notifications',
      channelDescription: 'High importance notifications for Khair app',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics = DarwinNotificationDetails(sound: 'default');
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );
    await _flutterLocalNotificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payload,
    );
  }
}
