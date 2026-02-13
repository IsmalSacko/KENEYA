import 'package:flutter/material.dart';

import '../models/user_model.dart';
import '../services/user_service.dart';

class UserController extends ChangeNotifier {
  final UserService _service = UserService();

  bool loading = false;
  String? error;
  bool lastActionQueued = false;
  List<UserModel> users = [];

  Future<void> fetchUsers() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _service.getUsersInMyEtablissements();
      users = data
          .map(
            (item) =>
                UserModel.fromJson(Map<String, dynamic>.from(item as Map)),
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
    lastActionQueued = false;
    notifyListeners();

    try {
      final result = await _service.addUser(
        name: name,
        telephone: telephone,
        role: role,
        pin: pin,
      );
      final queued = result['queued'] == true;
      lastActionQueued = queued;

      if (queued) {
        users = [
          UserModel(
            id: -DateTime.now().millisecondsSinceEpoch,
            etablissementId: null,
            name: name,
            telephone: telephone,
            role: role,
            actif: true,
          ),
          ...users,
        ];
        loading = false;
        notifyListeners();
      } else {
        final createdRaw = result['user'];
        if (createdRaw is Map) {
          final created = UserModel.fromJson(
            Map<String, dynamic>.from(createdRaw),
          );
          final exists = users.any((u) => u.id == created.id);
          if (!exists) {
            users = [created, ...users];
            notifyListeners();
          }
        }
        await fetchUsers();
      }
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
