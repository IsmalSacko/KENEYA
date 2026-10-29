import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../caisse/caisse_service.dart';
import '../../common/utils/kcolors.dart';
import '../../common/widgets/carte_marque.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../pharmacie/pharmacie_models.dart';
import '../../pharmacie/pharmacie_service.dart';
import '../pharmacie/vendre_screen.dart';
import 'ventes_du_jour.dart';
import 'assureurs_screen.dart';
import 'caisses_screen.dart';
import 'tarifs_screen.dart';
import 'visite_screen.dart';

/// La caisse : ouvrir et clôturer sa caisse, retrouver une visite (nom,
/// téléphone ou numéro de ticket), encaisser.
class CaisseTab extends StatefulWidget {
  const CaisseTab({super.key});

  @override
  State<CaisseTab> createState() => _CaisseTabState();
}

class _CaisseTabState extends State<CaisseTab> {
  final _service = CaisseService();
  final _recherche = TextEditingController();
  Map<String, dynamic>? _session;
  List<Visite> _visites = [];

  /// Officine : les ventes du jour remplacent la liste des visites.
  VentesDuJour? _ventes;
  String _devise = 'XOF';
  bool _chargement = true;
  String? _erreur;

  /// null : ouvertes (24 h) ; « impayees » ; « toutes » (24 h).
  String? _filtre;

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

  Future<void> _charger() async {
    try {
      final auth = context.read<AuthController>();
      if (auth.peut('caisse.encaisser')) {
        final s = await _service.session();
        _session = s['session'] is Map
            ? Map<String, dynamic>.from(s['session'] as Map)
            : null;
        _devise = (s['devise'] ?? 'XOF').toString();
      }
      if (auth.estOfficine && auth.aModule('pharmacie')) {
        _ventes = await PharmacieService().ventesDuJour();
      } else {
        _visites = await _service.visites(
          recherche: _recherche.text.trim(),
          filtre: _filtre,
        );
      }
      _erreur = null;
    } on DioException catch (e) {
      _erreur = messageErreur(e);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<int?> _demanderMontant(
    String titre,
    String aide, {
    bool obligatoire = false,
  }) {
    final ctrl = TextEditingController();
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titre),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d ,.]')),
          ],
          decoration: InputDecoration(labelText: '$aide ($_devise)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              // Une clôture sans comptage serait un faux écart.
              if (obligatoire && ctrl.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                lireMontant(ctrl.text.isEmpty ? '0' : ctrl.text, _devise),
              );
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
  }

  Future<void> _ouvrir() async {
    final fond = await _demanderMontant(
      'Ouvrir la caisse',
      'Fond de caisse en espèces',
    );
    if (fond == null) return;
    try {
      await _service.ouvrir(fond);
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _cloturer() async {
    final comptees = await _demanderMontant(
      'Clôturer la caisse',
      'Espèces comptées dans le tiroir',
      obligatoire: true,
    );
    if (comptees == null || !mounted) return;
    final s = _session;
    final attendu = s == null
        ? null
        : ((s['fond_initial'] as num?)?.toInt() ?? 0) +
              (((s['totaux'] as Map?)?['especes'] as num?)?.toInt() ?? 0);
    final ecartPrevu = attendu == null ? null : comptees - attendu;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer ma caisse ?'),
        content: Text(
          [
            if (attendu != null)
              'Espèces attendues : ${formatMontant(attendu, _devise)}',
            'Espèces comptées : ${formatMontant(comptees, _devise)}',
            if (ecartPrevu != null)
              ecartPrevu == 0
                  ? 'Aucun écart.'
                  : 'Écart : ${ecartPrevu > 0 ? '+' : ''}${formatMontant(ecartPrevu, _devise)}. Recomptez si besoin.',
            '\nUne caisse clôturée ne se rouvre pas.',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Recompter'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final r = await _service.cloturer(comptees);
      if (!mounted) return;
      final ecart = (r['ecart'] as num).toInt();
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Caisse clôturée'),
          content: Text(
            'Espèces attendues : ${formatMontant((r['especes_attendues'] as num).toInt(), _devise)}\n'
            'Espèces comptées : ${formatMontant(comptees, _devise)}\n'
            '${ecart == 0 ? 'Aucun écart.' : 'Écart : ${ecart > 0 ? '+' : ''}${formatMontant(ecart, _devise)}'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  /// Quelqu'un vient payer sans ticket : son nom (facultatif), puis la
  /// facture où l'on ajoute les actes.
  Future<void> _nouvelleFacture() async {
    final nom = TextEditingController();
    final telephone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nouvelle facture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nom,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nom du client (facultatif)',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: telephone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone (facultatif)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final v = await _service.nouvelleVisite(
        nom: nom.text.trim().isEmpty ? null : nom.text.trim(),
        telephone: telephone.text.trim().isEmpty ? null : telephone.text.trim(),
      );
      if (!mounted) return;
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => VisiteScreen(uuid: v.uuid)));
      _charger();
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
    final encaisse = auth.peut('caisse.encaisser');
    final totaux = _session?['totaux'] is Map
        ? Map<String, dynamic>.from(_session!['totaux'] as Map)
        : const <String, dynamic>{};

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (encaisse)
            CarteMarque(
              child: _session == null
                  ? Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Votre caisse est fermée.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Kolors.kJaune,
                            foregroundColor: Kolors.kPrimaryDark,
                            minimumSize: const Size(0, 48),
                          ),
                          onPressed: _ouvrir,
                          child: const Text('Ouvrir ma caisse'),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Encaissé dans ma caisse',
                          style: TextStyle(
                            color: Kolors.kWhite.withValues(alpha: 0.85),
                          ),
                        ),
                        Text(
                          formatMontant(
                            totaux.values.fold<int>(
                              0,
                              (s, v) => s + (v as num).toInt(),
                            ),
                            _devise,
                          ),
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Kolors.kJaune,
                          ),
                        ),
                        Wrap(
                          spacing: 12,
                          children: [
                            for (final e in totaux.entries)
                              Text(
                                '${libellesMoyens[e.key] ?? e.key} : ${formatMontant((e.value as num).toInt(), _devise)}',
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Kolors.kWhite,
                              side: BorderSide(
                                color: Kolors.kWhite.withValues(alpha: 0.6),
                              ),
                              minimumSize: const Size(0, 44),
                            ),
                            onPressed: _cloturer,
                            child: const Text('Clôturer ma caisse'),
                          ),
                        ),
                      ],
                    ),
            ),
          const SizedBox(height: 12),
          // La caisse prend aussi la main : une vente au comptoir, ou une
          // facture pour quelqu'un venu sans ticket.
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Dans une officine, on vend depuis l'onglet « Vendre ».
              if (!auth.estOfficine &&
                  auth.aModule('pharmacie') &&
                  auth.peut('pharmacie.delivrer'))
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Kolors.kJaune,
                    foregroundColor: Kolors.kPrimaryDark,
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const VendreScreen()),
                    );
                    _charger();
                  },
                  icon: const Icon(Icons.shopping_basket_outlined),
                  label: const Text('Nouvelle vente'),
                ),
              if (encaisse)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: _nouvelleFacture,
                  icon: const Icon(Icons.receipt_long_outlined),
                  label: const Text('Nouvelle facture'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_ventes != null) ...[
            if (auth.peut('caisse.rapports') ||
                auth.peut('etablissement.regler'))
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TarifsScreen()),
                  ),
                  icon: const Icon(Icons.price_change_outlined),
                  label: const Text('Tarifs et rapport'),
                ),
              ),
            VentesDuJourVue(
              jour: _ventes!,
              devise: _devise,
              onVente: (v) async {
                if (v.payee || v.annulee) {
                  final duJour =
                      v.le != null && DateUtils.isSameDay(v.le, DateTime.now());
                  await afficherRecu(
                    context,
                    v,
                    annuler: v.payee && duJour
                        ? () async {
                            try {
                              await PharmacieService().annulerVente(v.uuid);
                              _dire('Vente annulée : stock et argent rendus.');
                            } on DioException catch (e) {
                              _dire(messageErreur(e));
                            }
                            _charger();
                          }
                        : null,
                  );
                } else {
                  // En attente du caissier : l'encaisser, ou l'annuler
                  // (le stock revient).
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VisiteScreen(uuid: v.uuid),
                    ),
                  );
                  _charger();
                }
              },
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (auth.peut('caisse.rapports') ||
                    auth.peut('etablissement.regler'))
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TarifsScreen()),
                      );
                      _charger();
                    },
                    icon: const Icon(Icons.price_change_outlined),
                    label: const Text('Tarifs et rapport'),
                  ),
                if (auth.peut('caisse.rapports'))
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CaissesScreen(devise: _devise),
                      ),
                    ),
                    icon: const Icon(Icons.history_rounded),
                    label: const Text('Caisses clôturées'),
                  ),
                if (auth.aModule('assurances') &&
                    (auth.peut('assurances.gerer') ||
                        auth.peut('caisse.encaisser') ||
                        auth.peut('caisse.rapports')))
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AssureursScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.health_and_safety_outlined),
                    label: const Text('Assureurs'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recherche,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _charger(),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Nom, téléphone ou ticket (A012), puis Entrée',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _recherche.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _recherche.clear();
                          _charger();
                        },
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final (code, libelle) in const [
                  (null, 'Ouvertes'),
                  ('impayees', 'Impayées'),
                  ('toutes', 'Toutes (24 h)'),
                ])
                  ChoiceChip(
                    label: Text(libelle),
                    selected: _filtre == code,
                    onSelected: (_) {
                      setState(() => _filtre = code);
                      _charger();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_chargement)
              const Center(child: CircularProgressIndicator())
            else if (_erreur != null)
              Column(
                children: [
                  Text(_erreur!, style: const TextStyle(color: Kolors.kRed)),
                  TextButton.icon(
                    onPressed: _charger,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
                ],
              )
            else if (_visites.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _recherche.text.trim().isNotEmpty
                      ? 'Personne ne correspond à « ${_recherche.text.trim()} ».'
                      : _filtre == 'impayees'
                      ? 'Aucun impayé.'
                      : encaisse
                      ? 'Aucune visite ouverte. Un client sans ticket : « Nouvelle facture ».'
                      : 'Aucune visite ouverte.',
                  style: const TextStyle(color: Kolors.kTextMuted),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (final v in _visites)
                      ListTile(
                        title: Text(v.titre),
                        subtitle: Text(
                          [
                            if (v.ouverteAt != null &&
                                !DateUtils.isSameDay(
                                  v.ouverteAt,
                                  DateTime.now(),
                                ))
                              '${v.ouverteAt!.day.toString().padLeft(2, '0')}/${v.ouverteAt!.month.toString().padLeft(2, '0')}',
                            if (v.tickets.isNotEmpty) v.tickets.join(' → '),
                            if (v.telephone != null) v.telephone!,
                            if (v.statut == 'cloturee') 'clôturée',
                            if (v.statut == 'annulee') 'annulée',
                          ].join(' · '),
                        ),
                        trailing: Text(
                          v.reste > 0
                              ? formatMontant(v.reste, v.devise)
                              : (v.total > 0 ? 'Payé' : 'Pas encore facturé'),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: v.reste > 0
                                ? Kolors.kGold
                                : v.total > 0
                                ? Kolors.kSuccess
                                : Kolors.kTextMuted,
                          ),
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VisiteScreen(uuid: v.uuid),
                            ),
                          );
                          _charger();
                        },
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
