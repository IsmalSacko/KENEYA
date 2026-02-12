import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../core/storage/token_storage.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool initializing = true;
  bool loading = false;
  String? error;
  String? accessToken;
  UserModel? currentUser;

  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;

  AuthController() {
    restoreSession();
  }

  Future<void> restoreSession() async {
    initializing = true;
    notifyListeners();

    accessToken = await TokenStorage.getToken();

    initializing = false;
    notifyListeners();
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
    notifyListeners();

    try {
      final data = await _authService.register(
        nomEtablissement: nomEtablissement,
        type: type,
        name: name,
        telephone: telephone,
        pin: pin,
      );

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
      accessToken = null;
      currentUser = null;
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
