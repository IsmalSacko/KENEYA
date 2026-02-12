import '../core/api/api_client.dart';

class UserService {
  Future<List<dynamic>> getUsersInMyEtablissements() async {
    final response = await ApiClient.dio.get('/etablissements/users');
    return List<dynamic>.from(response.data as List);
  }

  Future<Map<String, dynamic>> addUser({
    required String name,
    required String telephone,
    required String role,
    required String pin,
  }) async {
    final response = await ApiClient.dio.post(
      '/users',
      data: {
        'name': name,
        'telephone': telephone,
        'role': role,
        'pin': pin,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateUser(
    int id,
    Map<String, dynamic> payload,
  ) async {
    final response = await ApiClient.dio.patch('/users/$id', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deleteUser(int id) async {
    await ApiClient.dio.delete('/users/$id');
  }
}
