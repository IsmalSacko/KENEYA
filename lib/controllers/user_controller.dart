import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';

class UserController extends ChangeNotifier {
  final UserService _service = UserService();

  bool loading = false;
  String? error;
  List<UserModel> users = [];

  Future<void> fetchUsers() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _service.getUsersInMyEtablissements();
      users = data
          .map(
            (item) => UserModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      error = 'Impossible de charger les utilisateurs.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> createUser({
    required String name,
    required String telephone,
    required String role,
    required String pin,
  }) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _service.addUser(
        name: name,
        telephone: telephone,
        role: role,
        pin: pin,
      );
      await fetchUsers();
      return true;
    } catch (_) {
      error = 'Echec de creation utilisateur.';
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser(int id, Map<String, dynamic> payload) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _service.updateUser(id, payload);
      await fetchUsers();
      return true;
    } catch (_) {
      error = 'Echec de mise a jour utilisateur.';
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(int id) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _service.deleteUser(id);
      users.removeWhere((u) => u.id == id);
      loading = false;
      notifyListeners();
      return true;
    } catch (_) {
      error = 'Echec de suppression utilisateur.';
      loading = false;
      notifyListeners();
      return false;
    }
  }
}
