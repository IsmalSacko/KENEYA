import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../caisse/caisse_service.dart';
import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../common/widgets/formulaire.dart';

/// Les tarifs de l'établissement (par catégorie, actifs ou non), et le
/// rapport de caisse d'une journée.
class TarifsScreen extends StatefulWidget {
  const TarifsScreen({super.key});

  @override
  State<TarifsScreen> createState() => _TarifsScreenState();
}

class _TarifsScreenState extends State<TarifsScreen> {
  final _service = CaisseService();
  final _recherche = TextEditingController();
  List<Tarif> _tarifs = [];
  Map<String, dynamic>? _rapport;
  DateTime _jour = DateTime.now();
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  String get _devise => context.read<AuthController>().devise;

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _charger() async {
    try {
      final t = await _service.tarifs();
      Map<String, dynamic>? r;
      if (mounted && context.read<AuthController>().peut('caisse.rapports')) {
        r = await _service.rapport(
          jour: DateFormat('yyyy-MM-dd').format(_jour),
        );
      }
      if (mounted) {
        setState(() {
          _tarifs = t;
          _rapport = r;
          _erreur = null;
        });
      }
    } on DioException catch (e) {
      if (mounted) setState(() => _erreur = messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _choisirJour() async {
    final choix = await showDatePicker(
      context: context,
      initialDate: _jour,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (choix == null) return;
    setState(() => _jour = choix);
    await _charger();
  }

  Future<void> _supprimer(Tarif t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer « ${t.nom} » ?'),
        content: const Text(
          'Il ne sera plus proposé. Les factures où il figure le gardent. Pour le retirer un temps, désactivez-le plutôt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Kolors.kRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.supprimerTarif(t.uuid);
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _editer([Tarif? t]) async {
    final nom = TextEditingController(text: t?.nom);
    final prix = TextEditingController(
      text: t == null
          ? ''
          : formatMontant(t.prix, _devise).replaceAll(RegExp(r'[^\d,]'), ''),
    );
    var categorie = t?.categorie ?? 'consultation';
    if (!libellesCategories.containsKey(categorie)) categorie = 'acte';
    var actif = t?.actif ?? true;
    String? erreur;
    final donnees = await formulaire<Map<String, dynamic>>(
      context,
      titre: Text(t == null ? 'Nouveau tarif' : 'Modifier le tarif'),
      corps: (ctx, setD) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nom,
            decoration: const InputDecoration(
              labelText: 'Acte (ex. Consultation générale)',
            ),
          ),
          TextField(
            controller: prix,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d ,.]')),
            ],
            decoration: InputDecoration(labelText: 'Prix ($_devise)'),
          ),
          DropdownButtonFormField<String>(
            initialValue: categorie,
            decoration: const InputDecoration(labelText: 'Catégorie'),
            items: [
              for (final c in libellesCategories.entries)
                DropdownMenuItem(value: c.key, child: Text(c.value)),
            ],
            onChanged: (v) => setD(() => categorie = v ?? categorie),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Proposé à la facturation'),
            subtitle: const Text('Désactivé, il est gardé mais pas proposé.'),
            value: actif,
            onChanged: (v) => setD(() => actif = v),
          ),
          if (erreur != null)
            Text(erreur!, style: const TextStyle(color: Kolors.kRed)),
        ],
      ),
      actions: (ctx, setD) => [
        if (t != null)
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Kolors.kRed),
            onPressed: () => Navigator.pop(ctx, {'supprimer': true}),
            child: const Text('Supprimer'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            final p = lireMontant(prix.text, _devise);
            if (nom.text.trim().isEmpty || p == null) {
              setD(() => erreur = 'Indiquez l’acte et son prix.');
              return;
            }
            Navigator.pop(ctx, {
              'nom': nom.text.trim(),
              'prix': p,
              'categorie': categorie,
              'actif': actif,
            });
          },
          child: const Text('Enregistrer'),
        ),
      ],
    );
    if (donnees == null) return;
    if (donnees['supprimer'] == true && t != null) return _supprimer(t);
    try {
      await _service.enregistrerTarif(donnees, uuid: t?.uuid);
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  int _n(dynamic v) => (v as num?)?.toInt() ?? 0;

  Widget _titre(String texte, {Widget? action}) => Row(
    children: [
      Expanded(
        child: Text(
          texte,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      ?action,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final r = _rapport;
    final q = _recherche.text.trim().toLowerCase();
    final visibles = _tarifs
        .where((t) => q.isEmpty || t.nom.toLowerCase().contains(q))
        .toList();
    final aujourdhui = DateUtils.isSameDay(_jour, DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Tarifs et rapport')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editer(),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau tarif'),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : _erreur != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_erreur!),
                  TextButton.icon(
                    onPressed: _charger,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _charger,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  if (r != null) ...[
                    _titre(
                      aujourdhui
                          ? 'Rapport d’aujourd’hui'
                          : 'Rapport du ${DateFormat('dd/MM/yyyy').format(_jour)}',
                      action: TextButton.icon(
                        onPressed: _choisirJour,
                        icon: const Icon(Icons.event_outlined),
                        label: const Text('Autre jour'),
                      ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r['visites']} visites · facturé ${formatMontant(_n(r['facture']), _devise)}',
                            ),
                            Text(
                              'Encaissé ${formatMontant(_n(r['encaisse']), _devise)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Kolors.kSuccess,
                              ),
                            ),
                            Text(
                              'Impayé ${formatMontant(_n(r['impaye']), _devise)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Kolors.kGold,
                              ),
                            ),
                            if (_n(r['part_assureurs']) > 0)
                              Text(
                                'À réclamer aux assureurs ${formatMontant(_n(r['part_assureurs']), _devise)}',
                              ),
                            const SizedBox(height: 8),
                            const Text(
                              'Par moyen de paiement',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            for (final m
                                in (r['par_moyen'] as List).cast<Map>())
                              Text(
                                '${libellesMoyens[m['moyen']] ?? m['moyen']} : ${formatMontant(_n(m['total']), _devise)} (${m['nombre']})',
                              ),
                            if ((r['par_categorie'] as List?)?.isNotEmpty ??
                                false) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Facturé par catégorie',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              for (final c
                                  in (r['par_categorie'] as List).cast<Map>())
                                Text(
                                  '${libellesCategories[c['categorie']] ?? (c['categorie'] == 'autre' ? 'Autres (médicaments, lignes libres)' : c['categorie'])} : ${formatMontant(_n(c['total']), _devise)}',
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _titre('Tarifs'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _recherche,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Chercher un acte',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_tarifs.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text(
                          'Aucun tarif. Ajoutez vos actes et leur prix.',
                        ),
                      ),
                    )
                  else if (visibles.isEmpty)
                    Text(
                      'Aucun acte ne correspond à « ${_recherche.text.trim()} ».',
                      style: const TextStyle(color: Kolors.kTextMuted),
                    ),
                  for (final c in {
                    ...libellesCategories.keys,
                    ...visibles.map((t) => t.categorie),
                  })
                    if (visibles.any((t) => t.categorie == c)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                        child: Text(
                          libellesCategories[c] ?? c,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Kolors.kTextMuted,
                          ),
                        ),
                      ),
                      Card(
                        child: Column(
                          children: [
                            for (final t in visibles.where(
                              (t) => t.categorie == c,
                            ))
                              ListTile(
                                title: Text(
                                  t.nom,
                                  style: TextStyle(
                                    color: t.actif ? null : Kolors.kTextMuted,
                                  ),
                                ),
                                subtitle: t.actif
                                    ? null
                                    : const Text('Désactivé'),
                                trailing: Text(
                                  formatMontant(t.prix, _devise),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: t.actif ? null : Kolors.kTextMuted,
                                  ),
                                ),
                                onTap: () => _editer(t),
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
