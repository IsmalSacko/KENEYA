import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/offline/local_store.dart';
import '../core/offline/sync_manager.dart';
import '../core/offline/sync_queue.dart';

class UserService {
  static const String _cacheKey = 'cache_users';

  Future<List<dynamic>> getUsersInMyEtablissements() async {
    try {
      final response = await ApiClient.dio.get('/etablissements/users');
      final data = List<dynamic>.from(response.data as List);
      await LocalStore.write(_cacheKey, data);
      return data;
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      return LocalStore.read<List<dynamic>>(_cacheKey) ?? <dynamic>[];
    }
  }

  Future<Map<String, dynamic>> addUser({
    required String name,
    required String telephone,
    required String role,
    required String pin,
  }) async {
    final payload = {
      'name': name,
      'telephone': telephone,
      'role': role,
      'pin': pin,
    };
    try {
      final response = await ApiClient.dio.post('/users', data: payload);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      await SyncQueue.enqueue(
        method: 'POST',
        path: '/users',
        payload: payload,
        cacheInvalidateKey: _cacheKey,
      );
      await SyncManager.instance.syncNow();
      return <String, dynamic>{'queued': true};
    }
  }

  Future<Map<String, dynamic>> updateUser(
    int id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await ApiClient.dio.patch('/users/$id', data: payload);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      await SyncQueue.enqueue(
        method: 'PATCH',
        path: '/users/$id',
        payload: payload,
        cacheInvalidateKey: _cacheKey,
      );
      await SyncManager.instance.syncNow();
      return <String, dynamic>{'queued': true};
    }
  }

  Future<void> deleteUser(int id) async {
    try {
      await ApiClient.dio.delete('/users/$id');
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      await SyncQueue.enqueue(
        method: 'DELETE',
        path: '/users/$id',
        cacheInvalidateKey: _cacheKey,
      );
      await SyncManager.instance.syncNow();
    }
  }
}
