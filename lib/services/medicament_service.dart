import '../core/api/api_client.dart';

class MedicamentService {
  Future<List<dynamic>> getMedicaments({bool lowStockOnly = false}) async {
    final response = await ApiClient.dio.get(
      '/medicaments',
      queryParameters: lowStockOnly ? {'low_stock': true} : null,
    );

    return List<dynamic>.from(response.data as List);
  }
}
