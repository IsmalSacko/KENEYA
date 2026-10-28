import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../common/utils/kcolors.dart';
import '../../core/api/api_client.dart';
import '../../maternite/maternite_models.dart';
import '../../maternite/maternite_service.dart';
import '../dossier/dossier_widgets.dart';
import 'grossesse_screen.dart';

/// Les grossesses suivies ici, le terme le plus proche d'abord ; les
/// terminées (accouchées, closes) à part.
class MaterniteTab extends StatefulWidget {
  const MaterniteTab({super.key});

  @override
  State<MaterniteTab> createState() => _MaterniteTabState();
}

class _MaterniteTabState extends State<MaterniteTab> {
  final _service = MaterniteService();
  final _recherche = TextEditingController();
  Timer? _attente;
  bool _terminees = false;
  List<Grossesse>? _liste;
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
      final l = await _service.grossesses(
        recherche: _recherche.text.trim(),
        terminees: _terminees,
      );
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

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('En cours')),
              ButtonSegment(value: true, label: Text('Accouchées et closes')),
            ],
            selected: {_terminees},
            onSelectionChanged: (s) {
              setState(() {
                _terminees = s.first;
                _liste = null;
              });
              _charger();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _recherche,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Nom de la patiente',
            ),
            onChanged: (_) {
              _attente?.cancel();
              _attente = Timer(const Duration(milliseconds: 350), _charger);
            },
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
                _terminees
                    ? 'Aucune grossesse terminée.'
                    : 'Aucune grossesse suivie. Elle se déclare depuis la visite de la patiente (Dossier › Grossesse).',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Kolors.kTextMuted),
              ),
            )
          else
            for (final g in l)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: g.enCours
                        ? Kolors.kJauneDoux
                        : Kolors.kGrayLight,
                    child: g.enCours
                        ? Text(
                            '${g.semaines ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: Kolors.kPrimaryDark,
                            ),
                          )
                        : Icon(
                            g.statut == 'accouchee'
                                ? Icons.child_friendly_rounded
                                : Icons.do_not_disturb_on_outlined,
                            color: Kolors.kPrimaryDark,
                          ),
                  ),
                  title: Text(g.patiente),
                  subtitle: Text(
                    g.enCours
                        ? [
                            'Terme ${dateCourte(DateTime.tryParse(g.dpa))}',
                            '${g.cpn.length} CPN',
                            if (g.prochainRdv != null)
                              'revoir le ${dateCourte(DateTime.tryParse(g.prochainRdv!))}',
                          ].join(' · ')
                        : [
                            g.fin,
                            if (g.accouchement != null)
                              'le ${dateCourte(g.accouchement)}'
                            else if (g.termineeLe != null)
                              'le ${dateCourte(DateTime.tryParse(g.termineeLe!))}',
                            '${g.cpn.length} CPN',
                          ].join(' · '),
                  ),
                  trailing: g.risques != null
                      ? const Tooltip(
                          message: 'À risque',
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Kolors.kRed,
                          ),
                        )
                      : null,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GrossesseScreen(grossesse: g),
                      ),
                    );
                    await _charger();
                  },
                ),
              ),
        ],
      ),
    );
  }
}
