import '../core/api/api_client.dart';

class EtablissementService {
  Future<Map<String, dynamic>> getMyScope() async {
    final response = await ApiClient.dio.get('/etablissements');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getOne(int id) async {
    final response = await ApiClient.dio.get('/etablissements/$id/show');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> update(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await ApiClient.dio.patch('/etablissements/$id', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> delete(int id) async {
    await ApiClient.dio.delete('/etablissements/$id');
  }
}
