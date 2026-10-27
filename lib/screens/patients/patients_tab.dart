import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../dossier/dossier_service.dart';
import '../../patients/patients_service.dart';
import '../commun/scanner_qr_screen.dart';
import '../dossier/dossier_screen.dart';
import 'patient_screen.dart';

/// Les patients : on les retrouve (nom, téléphone), on les enregistre une
/// fois, puis tout part de leur fiche.
class PatientsTab extends StatefulWidget {
  const PatientsTab({super.key});

  @override
  State<PatientsTab> createState() => _PatientsTabState();
}

class _PatientsTabState extends State<PatientsTab> {
  final _service = PatientsService();
  final _recherche = TextEditingController();
  Timer? _attente;
  List<Patient>? _liste;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _attente?.cancel();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final l = await _service.rechercher(_recherche.text.trim());
      if (mounted) {
        setState(() {
          _liste = l;
          _erreur = null;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _ouvrir(Patient p) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => PatientScreen(patient: p)));
    await _charger();
  }

  Future<void> _nouveau() async {
    try {
      final p = await nouveauPatient(context, recherche: _recherche.text);
      if (p != null && mounted) await _ouvrir(p);
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  /// Le soignant scanne le QR d'accord du patient : son historique s'ouvre.
  Future<void> _scannerAccord() async {
    final qr = await scannerQr(
      context,
      titre: 'QR d’accord',
      consigne: 'Le patient ouvre « Mon dossier » et montre son QR.',
    );
    if (qr == null || !mounted) return;
    try {
      final d = await DossierService().accorderParQr(qr);
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => DossierScreen(dossier: d)));
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final l = _liste;
    return Scaffold(
      floatingActionButton: auth.peut('patients.gerer')
          ? FloatingActionButton.extended(
              heroTag: 'nouveau-patient',
              onPressed: _nouveau,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Nouveau patient'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _recherche,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      labelText: 'Nom ou téléphone',
                    ),
                    onChanged: (_) {
                      _attente?.cancel();
                      _attente = Timer(
                        const Duration(milliseconds: 350),
                        _charger,
                      );
                    },
                  ),
                ),
                if (auth.peut('dossier.lire'))
                  IconButton(
                    tooltip: 'QR d’accord du patient',
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: _scannerAccord,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (l == null)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: _erreur == null
                      ? const CircularProgressIndicator()
                      : Text(_erreur!),
                ),
              )
            else if (l.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  _recherche.text.isEmpty
                      ? 'Aucun patient pour l’instant. Enregistrez-le à son arrivée : « Nouveau patient ».'
                      : 'Personne à ce nom. Nouveau ? Enregistrez-le.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Kolors.kTextMuted),
                ),
              )
            else
              for (final p in l)
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Kolors.kSecondaryLight,
                      child: Text(
                        p.nom.isEmpty ? '?' : p.nom.characters.first,
                        style: const TextStyle(
                          color: Kolors.kPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    title: Text(p.nom),
                    subtitle: Text(
                      [
                        p.resume,
                        ?p.telephone,
                      ].where((x) => x.isNotEmpty).join(' · '),
                    ),
                    onTap: () => _ouvrir(p),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
