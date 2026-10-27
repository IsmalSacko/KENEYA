import '../core/api/api_client.dart';

/// Réglages de l'établissement : modules actifs et droits de chaque rôle.
class ReglagesService {
  Future<void> modules(int etablissementId, List<String> modules) async {
    await ApiClient.dio.patch(
      '/etablissements/$etablissementId',
      data: {'modules': modules},
    );
  }

  Future<Map<String, dynamic>> droits() async {
    final res = await ApiClient.dio.get('/droits');
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> enregistrerDroits(String role, List<String> permissions) async {
    await ApiClient.dio.put(
      '/droits/$role',
      data: {'permissions': permissions},
    );
  }

  Future<void> droitsParDefaut(String role) async {
    await ApiClient.dio.delete('/droits/$role');
  }
}
