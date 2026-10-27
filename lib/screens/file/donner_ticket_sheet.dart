import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../common/utils/kcolors.dart';
import '../../file/file_models.dart';
import '../../file/file_service.dart';
import '../../patients/patients_service.dart';
import '../patients/choix_patient.dart';
import 'ticket_carte.dart';
import '../../common/widgets/feuille.dart';

/// À l'accueil : donner un ticket (service, priorité) au patient retrouvé
/// — sa visite s'ouvre dans sa fiche — ou, à défaut, à un nom et un
/// téléphone ; puis le montrer ou l'imprimer. Renvoie le ticket.
Future<TicketFile?> donnerTicket(
  BuildContext context,
  List<ServiceFile> services, {
  Patient? patient,
  bool consultation = false,
}) async {
  final ticket = await feuille<TicketFile>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FeuilleTicket(
      services: services.where((s) => s.actif).toList(),
      patient: patient,
      consultation: consultation,
    ),
  );
  if (ticket != null && context.mounted) {
    await afficherTicket(context, ticket);
  }
  return ticket;
}

class _FeuilleTicket extends StatefulWidget {
  const _FeuilleTicket({
    required this.services,
    this.patient,
    this.consultation = false,
  });

  final List<ServiceFile> services;
  final Patient? patient;

  /// « Envoyer en consultation » : le service Consultation est déjà coché.
  final bool consultation;

  @override
  State<_FeuilleTicket> createState() => _FeuilleTicketState();
}

class _FeuilleTicketState extends State<_FeuilleTicket> {
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  late String? _service =
      (widget.consultation
              ? widget.services
                    .where((s) => s.nom.toLowerCase().startsWith('consult'))
                    .firstOrNull
              : null)
          ?.uuid ??
      widget.services.firstOrNull?.uuid;
  late Patient? _patient = widget.patient;
  String _priorite = 'ordinaire';
  bool _envoi = false;

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (_service == null) return;
    setState(() => _envoi = true);
    try {
      final ticket = await FileService().emettre(
        serviceUuid: _service!,
        priorite: _priorite,
        nom: _patient == null ? _nom.text.trim() : null,
        telephone: _patient == null ? _telephone.text.trim() : null,
        dossierUuid: _patient?.uuid,
      );
      if (mounted) Navigator.pop(context, ticket);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data is Map && data['message'] != null
                  ? data['message'].toString()
                  : 'Ticket impossible. Vérifiez la connexion.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _envoi = false);
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Donner un ticket',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Kolors.kTextHigh,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in widget.services)
                  ChoiceChip(
                    label: Text('${s.nom} (${s.enAttente})'),
                    selected: _service == s.uuid,
                    onSelected: (_) => setState(() => _service = s.uuid),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Priorité',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in libellesPriorite.entries)
                  ChoiceChip(
                    label: Text(p.value),
                    selected: _priorite == p.key,
                    onSelected: (_) => setState(() => _priorite = p.key),
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Prioritaire : femme enceinte, personne âgée, handicap. L’urgence passe toujours en premier.',
                style: TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 14),
            ChoixPatient(
              patient: _patient,
              fixe: widget.patient != null,
              onChoisi: (p) => setState(() => _patient = p),
            ),
            if (_patient == null) ...[
              const SizedBox(height: 10),
              const Text(
                'Sinon (patient pas encore enregistré) :',
                style: TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 6),
            ],
            if (_patient == null) ...[
              TextField(
                controller: _nom,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom (facultatif)',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _telephone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone pour être prévenu par SMS (facultatif)',
                  prefixIcon: Icon(Icons.sms_outlined),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _envoi || _service == null ? null : _valider,
                child: _envoi
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Kolors.kWhite,
                        ),
                      )
                    : const Text('Donner le ticket'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
