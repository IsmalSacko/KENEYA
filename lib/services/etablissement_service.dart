import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/offline/local_store.dart';
import '../core/offline/sync_manager.dart';
import '../core/offline/sync_queue.dart';

class EtablissementService {
  static const String _scopeCacheKey = 'cache_etablissements_scope';

  Future<Map<String, dynamic>> getMyScope() async {
    try {
      final response = await ApiClient.dio.get('/etablissements');
      final data = Map<String, dynamic>.from(response.data as Map);
      await LocalStore.write(_scopeCacheKey, data);
      return data;
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      return LocalStore.read<Map<String, dynamic>>(_scopeCacheKey) ??
          <String, dynamic>{'etablissements': <dynamic>[]};
    }
  }

  Future<Map<String, dynamic>> getOne(int id) async {
    final response = await ApiClient.dio.get('/etablissements/$id/show');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> update(
    int id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await ApiClient.dio.patch(
        '/etablissements/$id',
        data: payload,
      );
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      await SyncQueue.enqueue(
        method: 'PATCH',
        path: '/etablissements/$id',
        payload: payload,
        cacheInvalidateKey: _scopeCacheKey,
      );
      await SyncManager.instance.syncNow();
      return <String, dynamic>{'queued': true};
    }
  }

  Future<void> delete(int id) async {
    try {
      await ApiClient.dio.delete('/etablissements/$id');
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      await SyncQueue.enqueue(
        method: 'DELETE',
        path: '/etablissements/$id',
        cacheInvalidateKey: _scopeCacheKey,
      );
      await SyncManager.instance.syncNow();
    }
  }
}
