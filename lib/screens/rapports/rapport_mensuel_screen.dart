import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';

/// Le rapport mensuel d'activité : ce que le district demande chaque mois
/// (fréquentation, consultations par âge et sexe, diagnostics, paludisme,
/// maternité, vaccination, hospitalisation, recettes). Il se copie pour
/// l'envoyer ou le recopier sur le canevas.
class RapportMensuelScreen extends StatefulWidget {
  const RapportMensuelScreen({super.key});

  @override
  State<RapportMensuelScreen> createState() => _RapportMensuelScreenState();
}

class _RapportMensuelScreenState extends State<RapportMensuelScreen> {
  DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, dynamic>? _r;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _r = null;
      _erreur = null;
    });
    try {
      final res = await ApiClient.dio.get(
        '/rapports/mensuel',
        queryParameters: {'mois': DateFormat('yyyy-MM').format(_mois)},
      );
      if (mounted) {
        setState(() => _r = Map<String, dynamic>.from(res.data as Map));
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    }
  }

  void _changer(int delta) {
    final m = DateTime(_mois.year, _mois.month + delta);
    if (m.isAfter(DateTime.now())) return;
    _mois = m;
    _charger();
  }

  Map<String, dynamic> _m(String cle) =>
      _r?[cle] is Map ? Map<String, dynamic>.from(_r![cle] as Map) : const {};

  int _n(Map<String, dynamic> m, String cle) => (m[cle] as num?)?.toInt() ?? 0;

  /// Le rapport en texte, à coller dans un message ou un canevas.
  String _texte(String devise) {
    final f = _m('frequentation'), c = _m('consultations'), p = _m('paludisme');
    final mat = _m('maternite'),
        h = _m('hospitalisation'),
        fin = _m('finances');
    final ages = c['par_age'] is Map
        ? Map<String, dynamic>.from(c['par_age'] as Map)
        : const {};
    final diag = _r?['diagnostics'] is List
        ? _r!['diagnostics'] as List
        : const [];
    final vacc = _m('vaccination');
    return [
      'Rapport d’activité ${DateFormat('MMMM yyyy', 'fr').format(_mois)} — ${_r?['etablissement'] ?? ''}',
      '',
      'Fréquentation : ${_n(f, 'visites')} visites, ${_n(f, 'patients')} patients, ${_n(f, 'nouveaux_patients')} nouveaux',
      'Consultations : ${_n(c, 'total')}',
      for (final e in ages.entries)
        if (((e.value as Map)['F'] as num) + ((e.value as Map)['M'] as num) > 0)
          '  ${e.key} : ${(e.value as Map)['F']} F, ${(e.value as Map)['M']} M',
      if (diag.isNotEmpty) 'Diagnostics :',
      for (final d in diag) '  ${(d as Map)['diagnostic']} : ${d['cas']}',
      'Paludisme : TDR ${_n(p, 'tdr')} (${_n(p, 'tdr_positifs')} +), GE ${_n(p, 'ge')} (${_n(p, 'ge_positives')} +)',
      'Maternité : CPN ${_n(mat, 'cpn')} (CPN1 ${_n(mat, 'cpn1')}, CPN4+ ${_n(mat, 'cpn4_et_plus')}, TPI ${_n(mat, 'tpi')}), accouchements ${_n(mat, 'accouchements')}, nés vivants ${_n(mat, 'naissances_vivantes')}, mort-nés ${_n(mat, 'mort_nes')}',
      if (vacc.isNotEmpty)
        'Vaccination : ${vacc.entries.map((e) => '${e.key} ${e.value}').join(', ')}',
      'Hospitalisation : ${_n(h, 'admissions')} admissions, ${_n(h, 'sorties')} sorties, ${_n(h, 'deces')} décès',
      'Recettes : facturé ${formatMontant(_n(fin, 'facture'), devise)}, encaissé ${formatMontant(_n(fin, 'encaisse'), devise)}',
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final devise = context.watch<AuthController>().devise;
    final r = _r;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport du mois'),
        actions: [
          if (r != null)
            IconButton(
              tooltip: 'Copier le rapport',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _texte(devise)));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Rapport copié : collez-le dans un message.',
                      ),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changer(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  toBeginningOfSentenceCase(
                    DateFormat('MMMM yyyy', 'fr').format(_mois),
                  ),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _changer(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (r == null)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: _erreur == null
                    ? const CircularProgressIndicator()
                    : Text(_erreur!),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  _texte(devise),
                  style: const TextStyle(height: 1.6),
                ),
              ),
            ),
          if (r != null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Les chiffres viennent de ce qui est saisi dans l’app : consultations, CPN, vaccins, analyses, caisse.',
                style: TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}
