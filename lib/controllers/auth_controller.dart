import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/offline/local_store.dart';
import '../core/offline/pin_cache.dart';
import '../core/offline/uuid.dart';
import '../core/storage/token_storage.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();
  static const String _offlineProfileKey = 'offline_provisional_profile';

  bool initializing = true;
  bool loading = false;
  String? error;
  bool lastRegisterQueued = false;
  bool offlineProvisionalSession = false;
  String? accessToken;
  UserModel? currentUser;

  /// Rempli quand le login renvoie 409 (numéro partagé par plusieurs
  /// établissements). La couche UI propose alors un choix, puis rappelle
  /// login(..., etablissementUuid: ...).
  List<Map<String, dynamic>> loginEtablissements = [];
  bool requiresEtablissementChoice = false;

  String _offlineLoginKey(String telephone) => 'offline_login_$telephone';

  Map<String, dynamic> _profileMap(UserModel u) => {
    'id': u.id,
    'etablissement_id': u.etablissementId,
    'name': u.name,
    'telephone': u.telephone,
    'role': u.role,
    'actif': u.actif,
  };

  UserModel? _parseUser(dynamic userJson) {
    if (userJson is Map<String, dynamic>) return UserModel.fromJson(userJson);
    if (userJson is Map) {
      return UserModel.fromJson(Map<String, dynamic>.from(userJson));
    }
    return null;
  }

  bool get isAuthenticated =>
      (accessToken != null && accessToken!.isNotEmpty) ||
      offlineProvisionalSession;

  AuthController() {
    restoreSession();
  }

  Future<void> restoreSession() async {
    initializing = true;
    notifyListeners();

    accessToken = await TokenStorage.getToken();
    if (accessToken == null || accessToken!.isEmpty) {
      final profile = LocalStore.read<Map<String, dynamic>>(_offlineProfileKey);
      if (profile != null) {
        currentUser = UserModel.fromJson(profile);
        offlineProvisionalSession = true;
      }
    } else {
      await refreshCurrentUser();
    }

    initializing = false;
    notifyListeners();
  }

  Future<void> refreshCurrentUser() async {
    if (accessToken == null || accessToken!.isEmpty) return;
    if (offlineProvisionalSession) return;

    try {
      final data = await _authService.getCurrentUser();
      currentUser = UserModel.fromJson(data);
      notifyListeners();
    } catch (_) {
      // Keep session even if profile refresh fails.
    }
  }

  Future<bool> login({
    required String telephone,
    required String pin,
    String? etablissementUuid,
  }) async {
    loading = true;
    error = null;
    requiresEtablissementChoice = false;
    loginEtablissements = [];
    notifyListeners();

    try {
      final data = await _authService.login(
        telephone,
        pin,
        etablissementUuid: etablissementUuid,
      );
      accessToken = (data['access_token'] ?? '').toString();
      currentUser = _parseUser(data['user']);

      if (accessToken != null && accessToken!.isNotEmpty) {
        offlineProvisionalSession = false;
        await LocalStore.remove(_offlineProfileKey);
        await TokenStorage.saveToken(accessToken!);

        // Mémorise de quoi se reconnecter hors-ligne plus tard.
        await PinCache.save(telephone, pin);
        if (currentUser != null) {
          await LocalStore.write(
            _offlineLoginKey(telephone),
            _profileMap(currentUser!),
          );
        }
        return true;
      }

      error = 'Token invalide.';
      return false;
    } on DioException catch (e) {
      // 409 : le numéro existe dans plusieurs établissements.
      if (e.response?.statusCode == 409) {
        final data = e.response?.data;
        if (data is Map && data['etablissements'] is List) {
          loginEtablissements = (data['etablissements'] as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          requiresEtablissementChoice = true;
        }
        error =
            (data is Map ? data['message']?.toString() : null) ??
            'Précisez l\'établissement.';
        return false;
      }

      // Hors-ligne : tenter la connexion via le cache local.
      if (ApiClient.isNetworkError(e)) {
        if (await _offlineLogin(telephone, pin)) return true;
        error =
            'Hors-ligne : identifiants non mis en cache. Connectez-vous une fois en ligne d\'abord.';
        return false;
      }

      error =
          _extractApiMessage(e) ??
          'Echec de connexion. Verifie telephone et PIN.';
      return false;
    } catch (_) {
      error = 'Echec de connexion. Verifie telephone et PIN.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Connexion hors-ligne : valide le PIN contre le cache sécurisé et restaure
  /// le profil mémorisé lors d'une précédente connexion en ligne.
  Future<bool> _offlineLogin(String telephone, String pin) async {
    if (!await PinCache.verify(telephone, pin)) return false;

    final profile = LocalStore.read<Map<String, dynamic>>(
      _offlineLoginKey(telephone),
    );
    if (profile == null) return false;

    currentUser = UserModel.fromJson(profile);
    accessToken = null;
    offlineProvisionalSession = true;
    return true;
  }

  Future<bool> register({
    required String nomEtablissement,
    required String type,
    required String name,
    required String telephone,
    required String pin,
  }) async {
    loading = true;
    error = null;
    lastRegisterQueued = false;
    notifyListeners();

    try {
      // uuid générés par le client → inscription idempotente au rejeu.
      final etablissementUuid = uuidV4();
      final userUuid = uuidV4();

      final data = await _authService.register(
        nomEtablissement: nomEtablissement,
        type: type,
        name: name,
        telephone: telephone,
        pin: pin,
        uuid: etablissementUuid,
        userUuid: userUuid,
      );

      // Permet de se (re)connecter hors-ligne dès l'inscription.
      await PinCache.save(telephone, pin);

      if (data['queued'] == true) {
        accessToken = null;
        currentUser = UserModel(
          id: -DateTime.now().millisecondsSinceEpoch,
          etablissementId: null,
          name: name,
          telephone: telephone,
          role: 'admin',
          actif: true,
        );
        offlineProvisionalSession = true;
        final profile = {
          'id': currentUser!.id,
          'etablissement_id': null,
          'uuid': userUuid,
          'name': currentUser!.name,
          'telephone': currentUser!.telephone,
          'role': currentUser!.role,
          'actif': true,
        };
        await LocalStore.write(_offlineProfileKey, profile);
        await LocalStore.write(_offlineLoginKey(telephone), profile);
        lastRegisterQueued = true;
        return true;
      }

      accessToken = (data['access_token'] ?? '').toString();
      currentUser = _parseUser(data['user']);

      if (accessToken != null && accessToken!.isNotEmpty) {
        offlineProvisionalSession = false;
        await LocalStore.remove(_offlineProfileKey);
        await TokenStorage.saveToken(accessToken!);
        if (currentUser != null) {
          await LocalStore.write(
            _offlineLoginKey(telephone),
            _profileMap(currentUser!),
          );
        }
        return true;
      }

      error = 'Token invalide apres inscription.';
      return false;
    } on DioException catch (e) {
      error = _extractApiMessage(e) ?? 'Echec de l\'inscription.';
      return false;
    } catch (_) {
      error = 'Echec de l\'inscription.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    loading = true;
    notifyListeners();

    try {
      await _authService.logout();
    } catch (_) {
      // Ignore API logout errors and clear local session.
    } finally {
      await TokenStorage.clearToken();
      await LocalStore.remove(_offlineProfileKey);
      accessToken = null;
      currentUser = null;
      offlineProvisionalSession = false;
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String telephone,
    String? pin,
  }) async {
    final userId = currentUser?.id;
    if (offlineProvisionalSession) {
      currentUser = UserModel(
        id: currentUser?.id ?? -1,
        etablissementId: currentUser?.etablissementId,
        name: name,
        telephone: telephone,
        role: currentUser?.role ?? 'admin',
        actif: currentUser?.actif ?? true,
      );
      await LocalStore.write(_offlineProfileKey, {
        'id': currentUser!.id,
        'etablissement_id': currentUser!.etablissementId,
        'name': currentUser!.name,
        'telephone': currentUser!.telephone,
        'role': currentUser!.role,
        'actif': currentUser!.actif,
      });
      notifyListeners();
      return true;
    }

    if (userId == null || userId <= 0) {
      error = 'Utilisateur invalide.';
      notifyListeners();
      return false;
    }

    loading = true;
    error = null;
    notifyListeners();

    try {
      final payload = <String, dynamic>{'name': name, 'telephone': telephone};
      if (pin != null && pin.trim().isNotEmpty) {
        payload['pin'] = pin.trim();
      }
      final data = await _authService.updateProfile(
        userId: userId,
        payload: payload,
      );
      final userJson = data['user'];
      if (userJson is Map<String, dynamic>) {
        currentUser = UserModel.fromJson(userJson);
      } else if (userJson is Map) {
        currentUser = UserModel.fromJson(Map<String, dynamic>.from(userJson));
      } else {
        currentUser = UserModel(
          id: currentUser!.id,
          etablissementId: currentUser!.etablissementId,
          name: name,
          telephone: telephone,
          role: currentUser!.role,
          actif: currentUser!.actif,
        );
      }

      if (offlineProvisionalSession) {
        await LocalStore.write(_offlineProfileKey, {
          'id': currentUser!.id,
          'etablissement_id': currentUser!.etablissementId,
          'name': currentUser!.name,
          'telephone': currentUser!.telephone,
          'role': currentUser!.role,
          'actif': currentUser!.actif,
        });
      }
      return true;
    } on DioException catch (e) {
      error = _extractApiMessage(e) ?? 'Echec de mise a jour du profil.';
      return false;
    } catch (_) {
      error = 'Echec de mise a jour du profil.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  String? _extractApiMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return null;
  }
}
