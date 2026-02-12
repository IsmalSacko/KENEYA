import 'package:flutter/material.dart';

import '../models/etablissement_model.dart';
import '../services/etablissement_service.dart';

class EtablissementController extends ChangeNotifier {
  final EtablissementService _service = EtablissementService();

  bool loading = false;
  String? error;
  List<EtablissementModel> etablissements = [];

  Future<void> fetchEtablissements() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _service.getMyScope();
      final rawList = data['etablissements'];
      if (rawList is List) {
        etablissements = rawList
            .map(
              (item) => EtablissementModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList();
      } else {
        etablissements = [];
      }
    } catch (_) {
      error = 'Impossible de charger les etablissements.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> updateEtablissement(
    int id,
    Map<String, dynamic> payload,
  ) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _service.update(id, payload);
      await fetchEtablissements();
      return true;
    } catch (_) {
      error = 'Echec de mise a jour etablissement.';
      loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteEtablissement(int id) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      await _service.delete(id);
      etablissements.removeWhere((e) => e.id == id);
      loading = false;
      notifyListeners();
      return true;
    } catch (_) {
      error = 'Echec de suppression etablissement.';
      loading = false;
      notifyListeners();
      return false;
    }
  }
}
