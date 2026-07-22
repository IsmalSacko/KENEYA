import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Cache local du PIN pour permettre la connexion **hors-ligne**.
///
/// Le PIN est conservé dans le stockage sécurisé du système (Keychain iOS /
/// Keystore Android, chiffré au repos), après une première connexion réussie
/// en ligne. Aucun secret n'est jamais exposé par le backend.
class PinCache {
  static const _storage = FlutterSecureStorage();

  static String _key(String telephone) => 'offline_pin_$telephone';

  static Future<void> save(String telephone, String pin) async {
    await _storage.write(key: _key(telephone), value: pin);
  }

  /// Vrai si un PIN est en cache pour ce numéro et qu'il correspond.
  static Future<bool> verify(String telephone, String pin) async {
    try {
      final stored = await _storage.read(key: _key(telephone));
      return stored != null && stored == pin;
    } on PlatformException {
      await _storage.delete(key: _key(telephone));
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> has(String telephone) async {
    try {
      return await _storage.read(key: _key(telephone)) != null;
    } catch (_) {
      return false;
    }
  }

  static Future<void> clear(String telephone) async {
    await _storage.delete(key: _key(telephone));
  }
}
