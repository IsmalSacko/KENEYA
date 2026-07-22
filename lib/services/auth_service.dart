import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/offline/sync_manager.dart';
import '../core/offline/sync_queue.dart';

class AuthService {
  /// Inscription. [uuid] / [userUuid] rendent l'opération idempotente : une
  /// inscription créée hors-ligne puis rejouée ne crée pas de doublon côté
  /// serveur (voir docs/OFFLINE_SYNC.md §8).
  Future<Map<String, dynamic>> register({
    required String nomEtablissement,
    required String type,
    required String name,
    required String telephone,
    required String pin,
    required String uuid,
    required String userUuid,
  }) async {
    final payload = {
      'nom_etablissement': nomEtablissement,
      'type': type,
      'name': name,
      'telephone': telephone,
      'pin': pin,
      'uuid': uuid,
      'user_uuid': userUuid,
    };
    try {
      final response = await ApiClient.dio.post('/register', data: payload);
      return Map<String, dynamic>.from(response.data as Map);
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) rethrow;
      await SyncQueue.enqueue(
        method: 'POST',
        path: '/register',
        payload: payload,
      );
      await SyncManager.instance.syncNow();
      return <String, dynamic>{'queued': true};
    }
  }

  /// Connexion. [etablissementUuid] lève l'ambiguïté quand un même numéro
  /// existe dans plusieurs établissements (le serveur répond alors 409).
  Future<Map<String, dynamic>> login(
    String telephone,
    String pin, {
    String? etablissementUuid,
  }) async {
    final response = await ApiClient.dio.post(
      '/login',
      data: {
        'telephone': telephone,
        'pin': pin,
        'etablissement_uuid': ?etablissementUuid,
      },
    );

    return Map<String, dynamic>.from(response.data as Map);
  }

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

  Future<Map<String, dynamic>> getCurrentUser() async {
    final response = await ApiClient.dio.get('/me');
    final data = Map<String, dynamic>.from(response.data as Map);
    final user = data['user'];
    if (user is Map) {
      return Map<String, dynamic>.from(user);
    }
    return data;
  }
}
