import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../common/utils/kcolors.dart';
import '../../core/api/api_client.dart';
import '../../rdv/rdv_models.dart';
import '../../patients/patients_service.dart';
import '../../rdv/rdv_service.dart';
import '../patients/choix_patient.dart';
import 'choix_creneau.dart';
import '../../common/widgets/feuille.dart';

/// L'accueil prend un rendez-vous au téléphone. Vrai si c'est réservé.
/// [patient] : on vient de sa fiche, il est déjà choisi.
Future<bool?> nouveauRdv(
  BuildContext context,
  List<AgendaRdv> agendas,
  DateTime jour, {
  Patient? patient,
}) async {
  final ouverts = agendas.where((a) => a.actif).toList();
  if (ouverts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          agendas.isEmpty
              ? 'Aucun agenda : créez-le dans Rendez-vous (icône calendrier).'
              : 'Tous les agendas sont en pause : rouvrez-en un dans Rendez-vous › Agendas.',
        ),
      ),
    );
    return null;
  }
  return feuille<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _NouveauRdv(agendas: ouverts, jour: jour, patient: patient),
  );
}

/// Un autre créneau : déplacer un rendez-vous, ou fixer l'heure d'une
/// demande venue sans heure. Renvoie l'agenda et le créneau choisis.
Future<(String, CreneauRdv)?> choisirCreneau(
  BuildContext context,
  List<AgendaRdv> agendas, {
  required String titre,
  required String action,
  String? agendaUuid,
  DateTime? depart,
}) async {
  final ouverts = agendas
      .where((a) => a.actif || a.uuid == agendaUuid)
      .toList();
  if (ouverts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aucun agenda ouvert : rouvrez-en un dans Agendas.'),
      ),
    );
    return null;
  }
  return feuille<(String, CreneauRdv)>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AutreCreneau(
      agendas: ouverts,
      agenda: ouverts.any((a) => a.uuid == agendaUuid)
          ? agendaUuid!
          : ouverts.first.uuid,
      depart: depart,
      titre: titre,
      action: action,
    ),
  );
}

class _AutreCreneau extends StatefulWidget {
  const _AutreCreneau({
    required this.agendas,
    required this.agenda,
    required this.titre,
    required this.action,
    this.depart,
  });

  final List<AgendaRdv> agendas;
  final String agenda;
  final String titre;
  final String action;
  final DateTime? depart;

  @override
  State<_AutreCreneau> createState() => _AutreCreneauState();
}

class _AutreCreneauState extends State<_AutreCreneau> {
  late String _agenda = widget.agenda;
  CreneauRdv? _creneau;

  @override
  Widget build(BuildContext context) {
    final agenda = widget.agendas.firstWhere((a) => a.uuid == _agenda);
    final aujourdhui = DateUtils.dateOnly(DateTime.now());
    final depart = widget.depart == null || widget.depart!.isBefore(aujourdhui)
        ? aujourdhui
        : widget.depart;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.titre,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Kolors.kTextHigh,
              ),
            ),
            const SizedBox(height: 10),
            if (widget.agendas.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: _agenda,
                decoration: const InputDecoration(labelText: 'Agenda'),
                items: [
                  for (final a in widget.agendas)
                    DropdownMenuItem(value: a.uuid, child: Text(a.nom)),
                ],
                onChanged: (v) => setState(() {
                  _agenda = v ?? _agenda;
                  _creneau = null;
                }),
              ),
              const SizedBox(height: 10),
            ],
            ChoixCreneau(
              key: ValueKey(_agenda),
              depart: depart,
              horizonJours: agenda.horizonJours,
              charger: (jour) => RdvService().creneaux(_agenda, jour, jour),
              onChoisi: (c) => setState(() => _creneau = c),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _creneau == null
                    ? null
                    : () => Navigator.pop(context, (_agenda, _creneau!)),
                child: Text(widget.action),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NouveauRdv extends StatefulWidget {
  const _NouveauRdv({required this.agendas, required this.jour, this.patient});

  final List<AgendaRdv> agendas;
  final DateTime jour;
  final Patient? patient;

  @override
  State<_NouveauRdv> createState() => _NouveauRdvState();
}

class _NouveauRdvState extends State<_NouveauRdv> {
  final _service = RdvService();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _motif = TextEditingController();
  late String _agenda = widget.agendas.first.uuid;
  CreneauRdv? _creneau;
  late Patient? _patient = widget.patient;
  bool _envoi = false;

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _motif.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (_creneau == null || (_patient == null && _nom.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une heure et le patient.')),
      );
      return;
    }
    setState(() => _envoi = true);
    try {
      await _service.reserver(
        agendaUuid: _agenda,
        debut: _creneau!.debut,
        dossierUuid: _patient?.uuid,
        nom: _nom.text.trim(),
        telephone: _telephone.text.trim(),
        motif: _motif.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _envoi = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Nouveau rendez-vous',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Kolors.kTextHigh,
              ),
            ),
            const SizedBox(height: 10),
            if (widget.agendas.length > 1)
              DropdownButtonFormField<String>(
                initialValue: _agenda,
                decoration: const InputDecoration(labelText: 'Agenda'),
                items: [
                  for (final a in widget.agendas)
                    DropdownMenuItem(value: a.uuid, child: Text(a.nom)),
                ],
                onChanged: (v) => setState(() => _agenda = v ?? _agenda),
              ),
            const SizedBox(height: 10),
            ChoixCreneau(
              key: ValueKey(_agenda),
              depart: widget.jour,
              horizonJours: widget.agendas
                  .firstWhere((a) => a.uuid == _agenda)
                  .horizonJours,
              charger: (jour) => _service.creneaux(_agenda, jour, jour),
              onChoisi: (c) => _creneau = c,
            ),
            const SizedBox(height: 12),
            ChoixPatient(
              patient: _patient,
              fixe: widget.patient != null,
              onChoisi: (p) => setState(() => _patient = p),
            ),
            if (_patient == null) ...[
              const SizedBox(height: 10),
              const Text(
                'Nouveau patient : il sera enregistré avec ce rendez-vous.',
                style: TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nom,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom du patient',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _telephone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone (pour le rappel)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _motif,
              decoration: const InputDecoration(
                labelText: 'Motif (facultatif)',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _envoi ? null : _valider,
                child: const Text('Réserver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
