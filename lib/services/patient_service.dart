import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/offline/local_store.dart';

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
}
