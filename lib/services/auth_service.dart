import '../core/api/api_client.dart';

class AuthService {
  Future<Map<String, dynamic>> register({
    required String nomEtablissement,
    required String type,
    required String name,
    required String telephone,
    required String pin,
  }) async {
    final response = await ApiClient.dio.post(
      '/register',
      data: {
        'nom_etablissement': nomEtablissement,
        'type': type,
        'name': name,
        'telephone': telephone,
        'pin': pin,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> login(String telephone, String pin) async {
    final response = await ApiClient.dio.post(
      '/login',
      data: {'telephone': telephone, 'pin': pin},
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> logout() async {
    await ApiClient.dio.post('/deconnexion');
  }
}
