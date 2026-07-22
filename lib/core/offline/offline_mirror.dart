import 'local_store.dart';

/// Miroir local des données serveur, alimenté par le pull de synchronisation.
///
/// Chaque table est stockée sous forme d'une map `uuid -> enregistrement`,
/// ce qui rend les upserts et suppressions idempotents. Le curseur global
/// `last_pulled_rev` permet des pulls delta.
class OfflineMirror {
  OfflineMirror._();

  static const String _revKey = 'sync_last_pulled_rev';

  static int get lastPulledRev => LocalStore.read<int>(_revKey) ?? 0;

  static Future<void> setLastPulledRev(int rev) async {
    await LocalStore.write(_revKey, rev);
  }

  static String _tableKey(String table) => 'mirror_$table';

  /// Enregistrements vivants d'une table (ordre non garanti).
  static List<Map<String, dynamic>> readTable(String table) {
    final raw = LocalStore.read<Map>(_tableKey(table));
    if (raw == null) return <Map<String, dynamic>>[];
    return raw.values
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Applique le résultat d'un pull : `{ table: { upserted, deleted } }`.
  /// Renvoie le nombre total d'enregistrements touchés.
  static Future<int> applyPull(Map<String, dynamic> changes) async {
    var touched = 0;

    for (final entry in changes.entries) {
      final table = entry.key;
      final value = entry.value;
      if (value is! Map) continue;

      final store = <String, dynamic>{};
      final current = LocalStore.read<Map>(_tableKey(table));
      if (current != null) {
        current.forEach((k, v) {
          if (v is Map) store[k.toString()] = Map<String, dynamic>.from(v);
        });
      }

      final upserted = value['upserted'];
      if (upserted is List) {
        for (final rec in upserted) {
          if (rec is Map && rec['uuid'] != null) {
            store[rec['uuid'].toString()] = Map<String, dynamic>.from(rec);
            touched++;
          }
        }
      }

      final deleted = value['deleted'];
      if (deleted is List) {
        for (final uuid in deleted) {
          if (store.remove(uuid.toString()) != null) touched++;
        }
      }

      await LocalStore.write(_tableKey(table), store);
    }

    return touched;
  }

  static Future<void> clear() async {
    await LocalStore.remove(_revKey);
  }
}
