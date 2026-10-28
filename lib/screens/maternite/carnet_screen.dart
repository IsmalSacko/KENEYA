import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../common/utils/kcolors.dart';
import '../../core/api/api_client.dart';
import '../../maternite/maternite_models.dart';
import '../../maternite/maternite_service.dart';
import '../dossier/dossier_widgets.dart';

/// Le carnet de vaccination de l'enfant : le soignant coche le vaccin fait.
class CarnetScreen extends StatefulWidget {
  const CarnetScreen({required this.dossierUuid, super.key});

  final String dossierUuid;

  @override
  State<CarnetScreen> createState() => _CarnetScreenState();
}

class _CarnetScreenState extends State<CarnetScreen> {
  final _service = MaterniteService();
  CarnetEnfant? _c;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _service
        .carnet(widget.dossierUuid)
        .then((c) {
          if (mounted) setState(() => _c = c);
        })
        .catchError((Object e) {
          if (mounted) {
            setState(
              () => _erreur = e is DioException
                  ? messageErreur(e)
                  : 'Indisponible.',
            );
          }
        });
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _vacciner(VaccinCarnet v) async {
    final lot = TextEditingController();
    final aujourdhui = DateUtils.dateOnly(DateTime.now());
    final naissance = DateTime.tryParse(_c?.enfant.dateNaissance ?? '');
    // Un vaccin fait ailleurs ou oublié se note à sa vraie date.
    var le = aujourdhui;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(v.nom),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_rounded),
                  title: Text(
                    le == aujourdhui
                        ? 'Fait aujourd’hui'
                        : 'Fait le ${dateCourte(le)}',
                  ),
                  subtitle: const Text('Toucher pour changer la date'),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: le,
                      firstDate:
                          naissance ??
                          aujourdhui.subtract(const Duration(days: 365 * 6)),
                      lastDate: aujourdhui,
                      helpText: 'Date du vaccin',
                    );
                    if (d != null) setState(() => le = d);
                  },
                ),
                TextField(
                  controller: lot,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de lot (facultatif)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Noter'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final c = await _service.vacciner(
        widget.dossierUuid,
        v.code,
        lot: lot.text.trim(),
        faitLe: DateFormat('yyyy-MM-dd').format(le),
      );
      if (mounted) setState(() => _c = c);
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _annuler(VaccinCarnet v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ce vaccin ?'),
        content: Text(
          '${v.nom}, noté le ${dateCourte(DateTime.tryParse(v.faitLe ?? ''))}. Pour un vaccin noté par erreur : il redevient à faire.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Annuler ce vaccin'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final c = await _service.annulerVaccin(widget.dossierUuid, v.code);
      if (mounted) setState(() => _c = c);
      _dire('Vaccin retiré du carnet.');
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      appBar: AppBar(title: Text(c?.enfant.nom ?? 'Carnet de vaccination')),
      body: c == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                CarnetVaccins(c, onVacciner: _vacciner, onAnnuler: _annuler),
              ],
            ),
    );
  }
}

/// Le carnet, vaccin par vaccin. Sans [onVacciner] : en lecture seule.
/// [onAnnuler] retire un vaccin noté par erreur.
class CarnetVaccins extends StatelessWidget {
  const CarnetVaccins(this.c, {this.onVacciner, this.onAnnuler, super.key});

  final CarnetEnfant c;
  final void Function(VaccinCarnet)? onVacciner;
  final void Function(VaccinCarnet)? onAnnuler;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          [
            if (c.enfant.dateNaissance != null)
              'Né(e) le ${dateCourte(DateTime.tryParse(c.enfant.dateNaissance!))}',
            if (c.enRetard > 0)
              '${c.enRetard} vaccin${c.enRetard > 1 ? 's' : ''} en retard',
          ].join(' · '),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: c.enRetard > 0 ? Kolors.kRed : Kolors.kTextHigh,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final v in c.vaccins)
                ListTile(
                  dense: true,
                  leading: Icon(
                    v.fait
                        ? Icons.check_circle_rounded
                        : v.enRetard
                        ? Icons.error_outline_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: v.fait
                        ? Kolors.kSuccess
                        : v.enRetard
                        ? Kolors.kRed
                        : Kolors.kTextMuted,
                  ),
                  title: Text(v.nom),
                  subtitle: Text(
                    v.fait
                        ? 'Fait le ${dateCourte(DateTime.tryParse(v.faitLe!))}${v.lieu == null ? '' : ' · ${v.lieu}'}'
                        : v.prevuLe == null
                        ? 'À faire'
                        : 'Prévu le ${dateCourte(DateTime.tryParse(v.prevuLe!))}',
                  ),
                  trailing: !v.fait && onVacciner != null
                      ? TextButton(
                          onPressed: () => onVacciner!(v),
                          child: const Text('Fait'),
                        )
                      : v.fait && onAnnuler != null
                      ? PopupMenuButton<void>(
                          tooltip: 'Plus',
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              onTap: () => onAnnuler!(v),
                              child: const Text('Annuler ce vaccin'),
                            ),
                          ],
                        )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
