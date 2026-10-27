import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../common/utils/kcolors.dart';
import '../../patients/patients_service.dart';

/// Retrouver le patient par son nom ou son téléphone. Une fois choisi, il
/// s'affiche en carte ; [fixe] interdit d'en changer (on vient de sa fiche).
class ChoixPatient extends StatefulWidget {
  const ChoixPatient({
    required this.patient,
    required this.onChoisi,
    this.fixe = false,
    super.key,
  });

  final Patient? patient;
  final ValueChanged<Patient?> onChoisi;
  final bool fixe;

  @override
  State<ChoixPatient> createState() => _ChoixPatientState();
}

class _ChoixPatientState extends State<ChoixPatient> {
  final _recherche = TextEditingController();
  List<Patient> _trouves = [];
  Timer? _attente;

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  void _chercher(String texte) {
    _attente?.cancel();
    if (texte.trim().length < 2) {
      setState(() => _trouves = []);
      return;
    }
    _attente = Timer(const Duration(milliseconds: 350), () async {
      try {
        final l = await PatientsService().rechercher(texte.trim());
        if (mounted) setState(() => _trouves = l.take(5).toList());
      } on DioException {
        // La recherche est une aide : sans réseau, on saisit le nom.
      }
    });
  }

  String _detail(Patient p) =>
      [p.resume, ?p.telephone].where((x) => x.isNotEmpty).join(' · ');

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    if (p != null) {
      return Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: const Icon(Icons.person_rounded, color: Kolors.kPrimary),
          title: Text(p.nom),
          subtitle: _detail(p).isEmpty ? null : Text(_detail(p)),
          trailing: widget.fixe
              ? null
              : IconButton(
                  tooltip: 'Autre patient',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => widget.onChoisi(null),
                ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _recherche,
          decoration: const InputDecoration(
            labelText: 'Patient déjà venu ? Nom ou téléphone',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: _chercher,
        ),
        for (final t in _trouves)
          ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(t.nom),
            subtitle: _detail(t).isEmpty ? null : Text(_detail(t)),
            onTap: () {
              _recherche.clear();
              setState(() => _trouves = []);
              widget.onChoisi(t);
            },
          ),
      ],
    );
  }
}
