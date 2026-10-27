import '../core/api/api_client.dart';

class AuthService {
  Future<void> logout() async {
    await ApiClient.dio.post('/deconnexion');
  }

  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required Map<String, dynamic> payload,
  }) async {
    final response = await ApiClient.dio.patch('/users/$userId', data: payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Le membre connecté, son établissement et ses droits.
  Future<Map<String, dynamic>> moi() async {
    final response = await ApiClient.dio.get('/me');
    return Map<String, dynamic>.from(response.data as Map);
  }
}
