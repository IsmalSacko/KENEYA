import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../compte/compte_api.dart';
import '../../core/api/api_client.dart';
import '../../dossier/dossier_models.dart';
import '../dossier/dossier_widgets.dart';

/// Son dossier médical : ce que les soignants ont noté, qui y a accès, qui
/// l'a ouvert. Le QR d'accord laisse un nouveau soignant voir l'historique.
class MonDossierScreen extends StatefulWidget {
  const MonDossierScreen({super.key});

  @override
  State<MonDossierScreen> createState() => _MonDossierScreenState();
}

class _MonDossierScreenState extends State<MonDossierScreen> {
  final _api = CompteApi();
  MonDossier? _m;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final m = MonDossier.fromJson(await _api.monDossier());
      if (mounted) {
        setState(() {
          _m = m;
          _erreur = null;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  void _message(String texte) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texte)));

  Future<void> _modifier(DossierPatient d) async {
    final donnees = await editerInfosMedicales(context, d);
    if (donnees == null) return;
    try {
      await _api.modifierMonDossier(donnees);
      await _charger();
    } on DioException catch (e) {
      _message(messageErreur(e));
    }
  }

  Future<void> _montrerAccord() async {
    final Map<String, dynamic> accord;
    try {
      accord = await _api.accordDossier();
    } on DioException catch (e) {
      _message(messageErreur(e));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => _AccordDialog(
        qr: accord['qr'].toString(),
        expire: DateTime.tryParse('${accord['expire_at']}')?.toLocal(),
      ),
    );
    await _charger();
  }

  Future<void> _retirer(AccesAccorde a) async {
    try {
      await _api.retirerAcces(a.id);
      await _charger();
      _message('${a.etablissement} ne voit plus votre historique.');
    } on DioException catch (e) {
      _message(messageErreur(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    return Scaffold(
      appBar: AppBar(title: const Text('Mon dossier')),
      body: m == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  CarteMarque(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Montrer mon dossier à un soignant',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Il scanne votre QR et voit votre historique pendant 7 jours. Vous pouvez le retirer quand vous voulez.',
                          style: TextStyle(
                            color: Kolors.kWhite.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Kolors.kJaune,
                            foregroundColor: Kolors.kPrimaryDark,
                          ),
                          onPressed: _montrerAccord,
                          icon: const Icon(Icons.qr_code_2_rounded),
                          label: const Text('Afficher mon QR'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (m.dossier.resume.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        m.dossier.resume,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  BlocMedical(
                    m.dossier,
                    onModifier: () => _modifier(m.dossier),
                  ),
                  if (m.acces.isNotEmpty) ...[
                    const _Titre('Ils voient mon historique'),
                    Card(
                      child: Column(
                        children: [
                          for (final a in m.acces)
                            ListTile(
                              leading: const Icon(
                                Icons.lock_open_rounded,
                                color: Kolors.kWarning,
                              ),
                              title: Text(a.etablissement),
                              subtitle: Text(
                                'Jusqu’au ${dateCourte(a.expire)} · ${a.par == 'qr' ? 'par QR' : 'par code SMS'}',
                              ),
                              trailing: TextButton(
                                onPressed: () => _retirer(a),
                                child: const Text('Retirer'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const _Titre('Mes consultations'),
                  if (m.dossier.consultations.isEmpty)
                    const Text(
                      'Aucune consultation pour l’instant.',
                      style: TextStyle(color: Kolors.kTextMuted),
                    ),
                  for (final c in m.dossier.consultations) CarteConsultation(c),
                  if (m.dossier.analyses.isNotEmpty) ...[
                    const _Titre('Mes résultats d’analyses'),
                    for (final a in m.dossier.analyses) CarteAnalyses(a),
                  ],
                  if (m.lectures.isNotEmpty) ...[
                    const _Titre('Qui a ouvert mon dossier'),
                    Card(
                      child: Column(
                        children: [
                          for (final l in m.lectures.take(20))
                            ListTile(
                              dense: true,
                              leading: Icon(
                                l.historique
                                    ? Icons.history_rounded
                                    : Icons.visibility_outlined,
                                color: Kolors.kTextMuted,
                              ),
                              title: Text(
                                [l.etablissement, ?l.par].join(' · '),
                              ),
                              subtitle: Text(
                                '${l.le == null ? '' : DateFormat('d MMM yyyy, HH:mm', 'fr').format(l.le!)}'
                                '${l.historique ? ' · tout l’historique' : ''}',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        texte,
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Le QR d'accord, avec le temps qui reste.
class _AccordDialog extends StatefulWidget {
  const _AccordDialog({required this.qr, this.expire});

  final String qr;
  final DateTime? expire;

  @override
  State<_AccordDialog> createState() => _AccordDialogState();
}

class _AccordDialogState extends State<_AccordDialog> {
  late final Timer _horloge;

  @override
  void initState() {
    super.initState();
    _horloge = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _horloge.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reste = widget.expire?.difference(DateTime.now());
    final expire = reste != null && reste.isNegative;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CarteMarque(
                child: Column(
                  children: [
                    Text(
                      'À scanner par le soignant',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: expire ? 0.25 : 1,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Kolors.kWhite,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: QrImageView(data: widget.qr, size: 220),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      expire
                          ? 'Expiré : affichez-le à nouveau.'
                          : reste == null
                          ? 'Valable une fois.'
                          : 'Valable une fois, encore ${reste.inMinutes}:${(reste.inSeconds % 60).toString().padLeft(2, '0')}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Kolors.kJaune,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
