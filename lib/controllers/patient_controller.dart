import 'package:flutter/material.dart';

import '../models/patient_model.dart';
import '../services/patient_service.dart';

class PatientController extends ChangeNotifier {
  final PatientService _service = PatientService();

  bool loading = false;
  String? error;
  List<PatientModel> patients = [];

  Future<void> fetchPatients() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _service.getPatients();
      patients = data
          .map(
            (item) => PatientModel.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      error = 'Impossible de charger les patients.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
