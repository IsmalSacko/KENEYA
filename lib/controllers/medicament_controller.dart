import 'package:flutter/material.dart';

import '../models/medicament_model.dart';
import '../services/medicament_service.dart';

class MedicamentController extends ChangeNotifier {
  final MedicamentService _service = MedicamentService();

  bool loading = false;
  String? error;
  List<MedicamentModel> medicaments = [];

  Future<void> fetchMedicaments({bool lowStockOnly = false}) async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _service.getMedicaments(lowStockOnly: lowStockOnly);
      medicaments = data
          .map(
            (item) => MedicamentModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      error = 'Impossible de charger les medicaments.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
