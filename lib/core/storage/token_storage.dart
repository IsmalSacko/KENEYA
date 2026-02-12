import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _storage = FlutterSecureStorage();

  static const _tokenKey = 'auth_token';

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<String?> getToken() async {
    try {
      return _storage.read(key: _tokenKey);
    } on PlatformException {
      // Corrupted/invalid keystore entry (e.g. after reinstall/signing change).
      await _storage.delete(key: _tokenKey);
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }
}
