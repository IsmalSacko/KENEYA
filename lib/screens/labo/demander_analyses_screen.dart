import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../labo/labo_models.dart';
import '../../labo/labo_service.dart';

/// Le médecin coche les analyses ; elles s'ajoutent à la facture de la
/// visite et arrivent au labo.
class DemanderAnalysesScreen extends StatefulWidget {
  const DemanderAnalysesScreen({
    required this.visiteUuid,
    required this.patient,
    super.key,
  });

  final String visiteUuid;
  final String patient;

  @override
  State<DemanderAnalysesScreen> createState() => _DemanderAnalysesScreenState();
}

class _DemanderAnalysesScreenState extends State<DemanderAnalysesScreen> {
  final _service = LaboService();
  final _renseignements = TextEditingController();
  final _recherche = TextEditingController();
  final Set<String> _choisies = {};

  /// Les analyses écrites à la main, absentes du catalogue.
  final List<String> _autres = [];
  List<AnalyseLabo>? _catalogue;
  String? _erreur;
  bool _urgent = false;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _service
        .analyses()
        .then((l) {
          if (mounted) setState(() => _catalogue = l);
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

  Future<void> _valider() async {
    setState(() => _envoi = true);
    try {
      await _service.demander(
        visite: widget.visiteUuid,
        analyses: _choisies.toList(),
        autres: _autres,
        urgent: _urgent,
        renseignements: _renseignements.text.trim(),
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
    final devise = context.watch<AuthController>().devise;
    final tout = _catalogue;
    final cherche = _sansAccents(_recherche.text.trim());
    final l = tout == null || cherche.isEmpty
        ? tout
        : tout
              .where(
                (a) =>
                    _sansAccents(a.nom).contains(cherche) ||
                    _sansAccents(a.code).contains(cherche),
              )
              .toList();
    final nombre = _choisies.length + _autres.length;
    final total = (tout ?? [])
        .where((a) => _choisies.contains(a.uuid))
        .fold<int>(0, (s, a) => s + (a.prix ?? 0));

    return Scaffold(
      appBar: AppBar(title: Text('Analyses · ${widget.patient}')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _envoi || nombre == 0 ? null : _valider,
              child: Text(
                nombre == 0
                    ? 'Cochez les analyses'
                    : 'Demander $nombre analyse${nombre > 1 ? 's' : ''}'
                          '${total > 0 ? ' · ${formatMontant(total, devise)}' : ''}',
              ),
            ),
          ),
        ),
      ),
      body: l == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _renseignements,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Renseignements cliniques (ex. fièvre 39 °C)',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Urgent'),
                  value: _urgent,
                  onChanged: (v) => setState(() => _urgent = v),
                ),
                TextField(
                  controller: _recherche,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    labelText: 'Chercher une analyse',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (_recherche.text.trim().isNotEmpty)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    leading: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Kolors.kPrimary,
                    ),
                    title: Text('Ajouter « ${_recherche.text.trim()} »'),
                    subtitle: const Text(
                      'Pas dans la liste : le labo la reçoit telle quelle.',
                    ),
                    onTap: () => setState(() {
                      final nom = _recherche.text.trim();
                      if (!_autres.contains(nom)) _autres.add(nom);
                      _recherche.clear();
                    }),
                  ),
                if (_autres.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final a in _autres)
                          InputChip(
                            label: Text(a),
                            onDeleted: () => setState(() => _autres.remove(a)),
                          ),
                      ],
                    ),
                  ),
                for (final (i, a) in l.indexed) ...[
                  if (i == 0 || l[i - 1].categorie != a.categorie)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                      child: Text(
                        a.categorieLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Kolors.kTextMuted,
                        ),
                      ),
                    ),
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    value: _choisies.contains(a.uuid),
                    title: Text(a.nom),
                    subtitle: a.prix == null
                        ? null
                        : Text(formatMontant(a.prix!, devise)),
                    onChanged: (oui) => setState(
                      () => oui == true
                          ? _choisies.add(a.uuid)
                          : _choisies.remove(a.uuid),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

String _sansAccents(String s) {
  const avec = 'àâäéèêëîïôöùûüç';
  const sans = 'aaaeeeeiioouuuc';
  final b = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    final i = avec.indexOf(c);
    b.write(i < 0 ? c : sans[i]);
  }
  return b.toString();
}
