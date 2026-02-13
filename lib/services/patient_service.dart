import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/offline/local_store.dart';
import '../core/offline/sync_manager.dart';
import '../core/offline/sync_queue.dart';

class PatientService {
  static const String _cacheKey = 'cache_patients';

  Future<List<dynamic>> getPatients() async {
    try {
      final response = await ApiClient.dio.get('/patients');
      final data = List<dynamic>.from(response.data as List);
      await LocalStore.write(_cacheKey, data);
      return data;
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      return LocalStore.read<List<dynamic>>(_cacheKey) ?? <dynamic>[];
    }
  }

  Future<Map<String, dynamic>> addPatient({
    required String nom,
    String? telephone,
    String? adresse,
  }) async {
    final payload = <String, dynamic>{
      'nom': nom,
      'telephone': telephone,
      'adresse': adresse,
    };

    try {
      final response = await ApiClient.dio.post('/patients', data: payload);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      await SyncQueue.enqueue(
        method: 'POST',
        path: '/patients',
        payload: payload,
        cacheInvalidateKey: _cacheKey,
      );
      await SyncManager.instance.syncNow();
      return <String, dynamic>{'queued': true};
    }
  }
}
