import 'dart:convert';

import 'local_store.dart';

class SyncQueue {
  SyncQueue._();

  static const String _queueKey = 'sync_queue_v1';

  static List<Map<String, dynamic>> getAll() {
    final raw = LocalStore.read<List<dynamic>>(_queueKey) ?? <dynamic>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<void> enqueue({
    required String method,
    required String path,
    Map<String, dynamic>? payload,
    String? cacheInvalidateKey,
  }) async {
    final queue = getAll();
    queue.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'method': method,
      'path': path,
      'payload': payload,
      'cacheInvalidateKey': cacheInvalidateKey,
      'createdAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    await LocalStore.write(_queueKey, queue);
  }

  static Future<void> replaceAll(List<Map<String, dynamic>> items) async {
    // Normalize through json to keep GetStorage values plain.
    final normalized = jsonDecode(jsonEncode(items)) as List<dynamic>;
    await LocalStore.write(_queueKey, normalized);
  }
}
