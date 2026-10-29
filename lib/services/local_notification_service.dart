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
    // Le canal des notifications envoyées par Ngoni Santé (Firebase).
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'ngoni_sante',
            'Ngoni Santé',
            description: 'Établissements, rendez-vous et alertes',
            importance: Importance.high,
          ),
        );
  }

  static Future<void> show({
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ngoni_sante',
      'Ngoni Santé',
      channelDescription: 'Établissements, rendez-vous et alertes',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(_nextId++, title, body, details);
  }
}
