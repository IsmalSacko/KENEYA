import 'package:flutter/material.dart';

import '../models/patient_model.dart';
import '../services/patient_service.dart';

class PatientController extends ChangeNotifier {
  final PatientService _service = PatientService();

  bool loading = false;
  String? error;
  bool lastActionQueued = false;
  List<PatientModel> patients = [];

  Future<void> fetchPatients() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final data = await _service.getPatients();
      patients = data
          .map(
            (item) =>
                PatientModel.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList();
    } catch (_) {
      error = 'Impossible de charger les patients.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> createPatient({
    required String nom,
    String? telephone,
    String? adresse,
  }) async {
    loading = true;
    error = null;
    lastActionQueued = false;
    notifyListeners();

    try {
      final result = await _service.addPatient(
        nom: nom,
        telephone: telephone,
        adresse: adresse,
      );
      final queued = result['queued'] == true;
      lastActionQueued = queued;

      if (queued) {
        patients = [
          PatientModel(
            id: -DateTime.now().millisecondsSinceEpoch,
            etablissementId: 0,
            nom: nom,
            telephone: telephone,
            adresse: adresse,
          ),
          ...patients,
        ];
        loading = false;
        notifyListeners();
      } else {
        final raw = result['patient'];
        if (raw is Map) {
          final created = PatientModel.fromJson(Map<String, dynamic>.from(raw));
          if (!patients.any((p) => p.id == created.id)) {
            patients = [created, ...patients];
            notifyListeners();
          }
        }
        await fetchPatients();
      }
      return true;
    } catch (_) {
      error = 'Echec de creation patient.';
      loading = false;
      notifyListeners();
      return false;
    }
  }
}
