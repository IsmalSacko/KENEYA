import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static int _nextId = 1000;

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Sur Linux, le module refuse de démarrer sans ses réglages.
    const linux = LinuxInitializationSettings(defaultActionName: 'Ouvrir');
    const settings = InitializationSettings(android: android, linux: linux);
    await _plugin.initialize(settings);
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'keneya_activity',
      'Activité Ngoni Santé',
      channelDescription: 'Notifications des actions métier',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(_nextId++, title, body, details);
  }
}
