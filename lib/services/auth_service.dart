import '../core/api/api_client.dart';

class AuthService {
  Future<Map<String, dynamic>> login(String telephone, String pin) async {
    final response = await ApiClient.dio.post(
      '/login',
      data: {
        'telephone': telephone,
        'pin': pin,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> logout() async {
    await ApiClient.dio.post('/deconnexion');
  }
}
