import 'api_client.dart';

/// Ce que le serveur sait faire, lu au démarrage. Par défaut : pas de SMS,
/// l'app propose alors WhatsApp, le QR et l'accueil.
class OptionsServeur {
  OptionsServeur._();

  static bool sms = false;

  static Future<void> charger() async {
    try {
      final res = await ApiClient.dio.get('/options');
      final d = res.data;
      sms = d is Map && d['sms'] == true;
    } catch (_) {
      // Hors ligne : on garde la valeur prudente.
    }
  }
}
