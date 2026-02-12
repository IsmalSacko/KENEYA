import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/offline/local_store.dart';

class MedicamentService {
  static const String _cacheAllKey = 'cache_medicaments_all';
  static const String _cacheLowStockKey = 'cache_medicaments_low_stock';

  Future<List<dynamic>> getMedicaments({bool lowStockOnly = false}) async {
    final cacheKey = lowStockOnly ? _cacheLowStockKey : _cacheAllKey;
    try {
      final response = await ApiClient.dio.get(
        '/medicaments',
        queryParameters: lowStockOnly ? {'low_stock': true} : null,
      );
      final data = List<dynamic>.from(response.data as List);
      await LocalStore.write(cacheKey, data);
      return data;
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      return LocalStore.read<List<dynamic>>(cacheKey) ?? <dynamic>[];
    }
  }
}
