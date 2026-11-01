import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keneya_plus/core/push/notifications_push.dart';
import 'package:keneya_plus/services/local_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'iPhone : les notifications démarrent sans bloquer le lancement, Firebase reste éteint',
    () async {
      final appels = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dexterous.com/flutter/local_notifications'),
            (appel) async {
              appels.add(appel);
              return true;
            },
          );
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        // Sans réglages iPhone, le module levait une erreur avant runApp :
        // l'app restait sur l'écran de lancement.
        await LocalNotificationService.init();
        final reglages = Map<String, dynamic>.from(
          appels.single.arguments as Map,
        );
        expect(appels.single.method, 'initialize');
        // Aucune autorisation demandée au lancement.
        expect(reglages['requestAlertPermission'], isFalse);
        expect(reglages['requestSoundPermission'], isFalse);
        expect(reglages['requestBadgePermission'], isFalse);

        // Pas de GoogleService-Info.plist : ni Firebase ni jeton sur iPhone.
        await NotificationsPush.init();
        expect(await NotificationsPush.jeton(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
