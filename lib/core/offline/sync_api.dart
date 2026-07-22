import '../api/api_client.dart';

/// Appels aux endpoints de synchronisation du backend
/// (voir docs/OFFLINE_SYNC.md côté back-end).
class SyncApi {
  /// Récupère les changements serveur depuis le curseur [lastPulledRev].
  ///
  /// Réponse : `{ server_rev, changes: { table: { upserted, deleted } } }`.
  static Future<Map<String, dynamic>> pull({
    required int lastPulledRev,
    List<String>? tables,
  }) async {
    final response = await ApiClient.dio.post(
      '/sync/pull',
      data: {
        'last_pulled_rev': lastPulledRev,
        'tables': ?tables,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Pousse les changements locaux (upserts + suppressions) de façon idempotente.
  ///
  /// [changes] : `{ table: { upserted: [...], deleted: [uuid...] } }`.
  /// Réponse : `{ accepted, server_rev, applied, rejected }`.
  static Future<Map<String, dynamic>> push({
    required Map<String, dynamic> changes,
    required int lastPulledRev,
  }) async {
    final response = await ApiClient.dio.post(
      '/sync/push',
      data: {'last_pulled_rev': lastPulledRev, 'changes': changes},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }
}
