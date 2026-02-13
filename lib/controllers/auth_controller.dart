import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../core/offline/local_store.dart';
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

  Future<bool> login({required String telephone, required String pin}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _authService.login(telephone, pin);
      accessToken = (data['access_token'] ?? '').toString();
      final userJson = data['user'];
      if (userJson is Map<String, dynamic>) {
        currentUser = UserModel.fromJson(userJson);
      } else if (userJson is Map) {
        currentUser = UserModel.fromJson(Map<String, dynamic>.from(userJson));
      } else {
        currentUser = null;
      }

      if (accessToken != null && accessToken!.isNotEmpty) {
        offlineProvisionalSession = false;
        await LocalStore.remove(_offlineProfileKey);
        await TokenStorage.saveToken(accessToken!);
        return true;
      }

      error = 'Token invalide.';
      return false;
    } on DioException catch (e) {
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
      final data = await _authService.register(
        nomEtablissement: nomEtablissement,
        type: type,
        name: name,
        telephone: telephone,
        pin: pin,
      );

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
        await LocalStore.write(_offlineProfileKey, {
          'id': currentUser!.id,
          'etablissement_id': null,
          'name': currentUser!.name,
          'telephone': currentUser!.telephone,
          'role': currentUser!.role,
          'actif': true,
        });
        lastRegisterQueued = true;
        return true;
      }

      accessToken = (data['access_token'] ?? '').toString();
      final userJson = data['user'];
      if (userJson is Map<String, dynamic>) {
        currentUser = UserModel.fromJson(userJson);
      } else if (userJson is Map) {
        currentUser = UserModel.fromJson(Map<String, dynamic>.from(userJson));
      } else {
        currentUser = null;
      }

      if (accessToken != null && accessToken!.isNotEmpty) {
        offlineProvisionalSession = false;
        await LocalStore.remove(_offlineProfileKey);
        await TokenStorage.saveToken(accessToken!);
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
