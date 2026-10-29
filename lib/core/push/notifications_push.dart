import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../services/local_notification_service.dart';

/// Les notifications sur le téléphone (Firebase) : « établissement à
/// valider », « établissement validé »… Android seulement ; ailleurs rien ne
/// se passe. Le compte rattache le jeton à la personne connectée.
class NotificationsPush {
  NotificationsPush._();

  static bool _pret = false;

  static bool get _disponible => !kIsWeb && Platform.isAndroid;

  static Future<void> init() async {
    if (!_disponible || _pret) return;
    try {
      await Firebase.initializeApp();
      // App ouverte : Android ne l'affiche pas tout seul.
      FirebaseMessaging.onMessage.listen((message) {
        final n = message.notification;
        if (n == null) return;
        LocalNotificationService.show(
          title: n.title ?? 'Ngoni Santé',
          body: n.body ?? '',
        );
      });
      _pret = true;
    } catch (_) {
      // Firebase indisponible : l'app marche sans notifications.
    }
  }

  /// Le jeton de ce téléphone, après avoir demandé l'autorisation ; null
  /// sans Firebase ou si la personne refuse.
  static Future<String?> jeton() async {
    await init();
    if (!_pret) return null;
    try {
      await FirebaseMessaging.instance.requestPermission();
      // Le jeton d'enregistrement classique : celui que le serveur (comme
      // Ngoni Caisse) envoie à l'API FCM v1.
      // ignore: deprecated_member_use
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  /// Le jeton change parfois : il faut le redonner au serveur.
  static void surNouveauJeton(void Function(String jeton) rappel) {
    if (!_pret) return;
    // ignore: deprecated_member_use
    FirebaseMessaging.instance.onTokenRefresh.listen(rappel);
  }
}
