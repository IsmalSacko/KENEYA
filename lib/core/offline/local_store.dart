import 'package:get_storage/get_storage.dart';

class LocalStore {
  LocalStore._();

  static const String _container = 'keneya_offline';
  static final GetStorage _box = GetStorage(_container);

  static Future<void> init() async {
    await GetStorage.init(_container);
  }

  static T? read<T>(String key) {
    final value = _box.read(key);
    if (value is T) return value;
    return null;
  }

  static Future<void> write(String key, dynamic value) async {
    await _box.write(key, value);
  }

  static Future<void> remove(String key) async {
    await _box.remove(key);
  }
}
