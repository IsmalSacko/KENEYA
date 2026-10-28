import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../labo/labo_models.dart';
import '../../labo/labo_service.dart';
import '../commun/scanner_qr_screen.dart';
import 'catalogue_labo_screen.dart';
import 'demande_labo_screen.dart';

/// Le travail du labo : à prélever, à saisir, validé.
class LaboTab extends StatefulWidget {
  const LaboTab({super.key});

  @override
  State<LaboTab> createState() => _LaboTabState();
}

class _LaboTabState extends State<LaboTab> {
  final _service = LaboService();
  bool _validees = false;
  int _jours = 1;
  final _recherche = TextEditingController();
  Timer? _attente;
  List<DemandeLabo>? _liste;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _attente?.cancel();
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    try {
      final l = await _service.demandes(
        validees: _validees,
        jours: _jours,
        q: _recherche.text,
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

  Future<void> _ouvrir(DemandeLabo d) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => DemandeLaboScreen(demande: d)));
    await _charger();
  }

  Future<void> _scanner() async {
    final qr = await scannerQr(
      context,
      titre: 'Étiquette du tube',
      consigne: 'Visez le QR de l’étiquette.',
    );
    if (qr == null || !mounted) return;
    try {
      await _ouvrir(await _service.lire(qr));
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
    final auth = context.watch<AuthController>();
    final l = _liste;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'etiquette-labo',
        onPressed: _scanner,
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Étiquette'),
      ),
      body: RefreshIndicator(
        onRefresh: _charger,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('À faire')),
                ButtonSegment(value: true, label: Text('Validées')),
              ],
              selected: {_validees},
              onSelectionChanged: (s) {
                setState(() {
                  _validees = s.first;
                  _liste = null;
                });
                _charger();
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _recherche,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                labelText: 'Nom du patient',
              ),
              onChanged: (_) {
                _attente?.cancel();
                _attente = Timer(const Duration(milliseconds: 350), _charger);
              },
            ),
            if (_validees) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final (j, libelle) in const [
                    (1, '24 h'),
                    (7, '7 jours'),
                    (30, '30 jours'),
                    (90, '3 mois'),
                  ])
                    ChoiceChip(
                      label: Text(libelle),
                      selected: _jours == j,
                      onSelected: (_) {
                        setState(() => _jours = j);
                        _charger();
                      },
                    ),
                ],
              ),
            ],
            if (auth.peut('labo.valider') ||
                auth.peut('etablissement.regler')) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CatalogueLaboScreen(),
                  ),
                ),
                icon: const Icon(Icons.biotech_rounded),
                label: const Text('Analyses et prix'),
              ),
            ],
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
                  _recherche.text.trim().isNotEmpty
                      ? 'Aucune demande pour ce nom.'
                      : _validees
                      ? (_jours == 1
                            ? 'Aucun résultat validé ces dernières 24 h.'
                            : 'Aucun résultat validé sur cette période.')
                      : 'Rien à faire. Les demandes des médecins arrivent ici.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Kolors.kTextMuted),
                ),
              )
            else
              for (final d in l)
                Card(
                  child: ListTile(
                    leading: Icon(
                      d.urgent
                          ? Icons.priority_high_rounded
                          : d.statut == 'demandee'
                          ? Icons.water_drop_outlined
                          : d.validee
                          ? Icons.verified_rounded
                          : Icons.science_outlined,
                      color: d.urgent ? Kolors.kRed : Kolors.kPrimary,
                    ),
                    title: Text(d.patient),
                    subtitle: Text(
                      [
                        d.statut == 'demandee' && d.rejetMotif != null
                            ? 'À reprélever (${d.rejetMotif})'
                            : d.statutLabel,
                        d.lignes.map((x) => x.nom).join(', '),
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: d.anormaux > 0
                        ? Text(
                            '${d.anormaux} anormal${d.anormaux > 1 ? 'aux' : ''}',
                            style: const TextStyle(
                              color: Kolors.kRed,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                    onTap: () => _ouvrir(d),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
