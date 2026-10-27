import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  Future<void> _vacciner(VaccinCarnet v) async {
    final lot = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(v.nom),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Vaccin fait aujourd’hui.'),
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
    );
    if (ok != true) return;
    try {
      final c = await _service.vacciner(
        widget.dossierUuid,
        v.code,
        lot: lot.text.trim(),
      );
      if (mounted) setState(() => _c = c);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
      }
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
              children: [CarnetVaccins(c, onVacciner: _vacciner)],
            ),
    );
  }
}

/// Le carnet, vaccin par vaccin. Sans [onVacciner] : en lecture seule.
class CarnetVaccins extends StatelessWidget {
  const CarnetVaccins(this.c, {this.onVacciner, super.key});

  final CarnetEnfant c;
  final void Function(VaccinCarnet)? onVacciner;

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
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
