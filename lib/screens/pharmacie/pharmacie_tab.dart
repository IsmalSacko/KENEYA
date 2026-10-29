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
import '../../pharmacie/pharmacie_models.dart';
import '../../pharmacie/pharmacie_service.dart';
import '../../pharmacie/verification_ordonnance.dart';
import '../commun/scanner_qr_screen.dart';
import 'a_commander_screen.dart';
import 'delivrance_screen.dart';
import 'fournisseurs_screen.dart';
import 'rayons_screen.dart';
import 'historique_produit_screen.dart';
import 'inventaire_screen.dart';
import 'vendre_screen.dart';
import '../../common/widgets/feuille.dart';
import '../../common/widgets/formulaire.dart';

/// La pharmacie : délivrer (ordonnance scannée ou comptoir), et le stock
/// par lots avec ses alertes.
class PharmacieTab extends StatefulWidget {
  const PharmacieTab({super.key});

  @override
  State<PharmacieTab> createState() => _PharmacieTabState();
}

class _PharmacieTabState extends State<PharmacieTab> {
  final _service = PharmacieService();
  final _recherche = TextEditingController();
  List<Produit> _produits = [];
  List<PatientAServir> _aServir = [];
  Map<String, dynamic>? _alertes;
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    VerificationOrdonnance.rafraichirCle();
    _charger();
  }

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final delivre = context.read<AuthController>().peut('pharmacie.delivrer');
    try {
      await Rayons.charger();
      _produits = await _service.produits(recherche: _recherche.text.trim());
      _alertes = await _service.alertes();
      if (delivre) _aServir = await _service.aServir();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  /// Scanner une ordonnance : le serveur dit ce qui reste à délivrer ; sans
  /// internet, la signature se vérifie quand même sur le téléphone.
  Future<void> _scannerOrdonnance() async {
    final qr = await scannerQr(
      context,
      titre: 'Ordonnance',
      consigne: 'Scannez le QR de l’ordonnance',
    );
    if (qr == null || !mounted) return;
    try {
      final o = await _service.lireOrdonnance(qr);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DelivranceScreen(ordonnance: o)),
      );
      _charger();
    } on DioException catch (e) {
      if (!ApiClient.isNetworkError(e)) {
        _dire(messageErreur(e));
        return;
      }
      final contenu = await VerificationOrdonnance.verifier(qr);
      if (!mounted) return;
      if (contenu == null) {
        _dire(
          'Ordonnance non authentique (ou clé de vérification pas encore reçue).',
        );
        return;
      }
      final hl = OrdonnanceRx(
        uuid: (contenu['u'] ?? '').toString(),
        statut: 'emise',
        patientNom: (contenu['p'] ?? '').toString(),
        etablissement: (contenu['e'] ?? '').toString(),
        prescripteur: contenu['m']?.toString(),
        date: contenu['d']?.toString(),
        qr: qr,
        lignes: [
          for (final l in (contenu['l'] as List? ?? const []))
            LigneOrdonnance(
              uuid: '',
              produit: (l as List)[0].toString(),
              quantite: (l[1] as num).toInt(),
              delivree: 0,
              reste: (l[1] as num).toInt(),
              posologie: l.length > 2 ? l[2]?.toString() : null,
            ),
        ],
      );
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DelivranceScreen(ordonnance: hl, horsLigne: true),
        ),
      );
    }
  }

  /// Servir un patient de la liste : son ordonnance s'ouvre telle quelle,
  /// sans scanner ; s'il n'en a pas, une vente sur sa facture.
  Future<void> _servir(PatientAServir p) async {
    var o = p.ordonnances.firstOrNull;
    if (p.ordonnances.length > 1) {
      o = await feuille<OrdonnanceRx>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final x in p.ordonnances)
                ListTile(
                  leading: const Icon(Icons.receipt_long_rounded),
                  title: Text(x.prescripteur ?? 'Ordonnance'),
                  subtitle: Text(x.lignes.map((l) => l.produit).join(', ')),
                  onTap: () => Navigator.pop(ctx, x),
                ),
            ],
          ),
        ),
      );
      if (o == null) return;
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DelivranceScreen(ordonnance: o, visiteUuid: p.visiteUuid),
      ),
    );
    _charger();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final gereStock = auth.peut('stock.gerer');
    final delivre = auth.peut('pharmacie.delivrer');
    final a = _alertes;
    final nbAlertes = a == null
        ? 0
        : (a['stock_bas'] as List).length +
              (a['peremption_proche'] as List).length +
              (a['perimes'] as List).length;

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (delivre && _aServir.isNotEmpty) ...[
            _AServir(patients: _aServir, onServir: _servir),
            const SizedBox(height: 16),
          ],
          // Dans une officine, on vend et on scanne depuis l'onglet « Vendre ».
          if (delivre && !auth.estOfficine) ...[
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Kolors.kJaune,
                  foregroundColor: Kolors.kPrimaryDark,
                ),
                onPressed: _scannerOrdonnance,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scanner une ordonnance'),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () async {
                await Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const VendreScreen()));
                _charger();
              },
              icon: const Icon(Icons.shopping_basket_outlined),
              label: const Text('Vente au comptoir'),
            ),
            const SizedBox(height: 16),
          ],
          if (nbAlertes > 0) _Alertes(alertes: a!),
          TextField(
            controller: _recherche,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _charger(),
            decoration: const InputDecoration(
              hintText: 'Produit ou molécule',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          if (gereStock) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () async {
                    await editerProduit(context);
                    _charger();
                  },
                  icon: const Icon(Icons.add_box_outlined),
                  label: const Text('Nouveau produit'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReceptionScreen(produits: _produits),
                      ),
                    );
                    _charger();
                  },
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Réception'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const InventaireScreen(),
                      ),
                    );
                    _charger();
                  },
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Inventaire'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ACommanderScreen()),
                  ),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('À commander'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FournisseursScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Fournisseurs'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RayonsScreen()),
                    );
                    _charger();
                  },
                  icon: const Icon(Icons.category_outlined),
                  label: const Text('Catégories'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          if (_chargement)
            const Center(child: CircularProgressIndicator())
          else if (_produits.isEmpty)
            const Text(
              'Aucun produit. Ajoutez vos produits, puis la première livraison.',
              style: TextStyle(color: Kolors.kTextMuted),
            )
          else if (_visibles.isEmpty)
            Text(
              'Aucun produit ne correspond à « ${_recherche.text.trim()} ».',
              style: const TextStyle(color: Kolors.kTextMuted),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final p in _visibles)
                    ExpansionTile(
                      title: Text(
                        p.nom,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          if (p.description.isNotEmpty) p.description,
                          p.stockLabel,
                        ].join(' · '),
                        style: TextStyle(
                          color: p.stockBas ? Kolors.kRed : Kolors.kTextMuted,
                        ),
                      ),
                      children: [
                        for (final l in p.lots)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              l.perime
                                  ? Icons.dangerous_rounded
                                  : Icons.inventory_2_outlined,
                              color: l.perime ? Kolors.kRed : Kolors.kPrimary,
                            ),
                            title: Text(
                              'Lot ${l.numero ?? 'sans numéro'} · ${l.quantite} unité(s)',
                            ),
                            subtitle: Text(
                              l.peremption == null
                                  ? 'Péremption inconnue'
                                  : 'Périme le ${l.peremption}',
                            ),
                            trailing: gereStock
                                ? PopupMenuButton<String>(
                                    tooltip: 'Actions sur le lot',
                                    onSelected: (a) => _actionLot(a, l),
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'compter',
                                        child: Text('Compter (inventaire)'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'corriger',
                                        child: Text(
                                          'Corriger le numéro ou la péremption',
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'retirer',
                                        child: Text(
                                          'Retirer du stock (périmé, abîmé…)',
                                        ),
                                      ),
                                      if (l.intact)
                                        const PopupMenuItem(
                                          value: 'annuler',
                                          child: Text(
                                            'Annuler la réception (erreur)',
                                          ),
                                        ),
                                    ],
                                  )
                                : null,
                          ),
                        if (gereStock)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Wrap(
                              spacing: 4,
                              alignment: WrapAlignment.center,
                              children: [
                                TextButton.icon(
                                  onPressed: () async {
                                    await editerProduit(context, p);
                                    _charger();
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Modifier'),
                                ),
                                TextButton.icon(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          HistoriqueProduitScreen(produit: p),
                                    ),
                                  ),
                                  icon: const Icon(Icons.history_rounded),
                                  label: const Text('Historique'),
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Kolors.kRed,
                                  ),
                                  onPressed: () => _supprimerProduit(p),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Supprimer'),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// La recherche filtre pendant la frappe ; Entrée interroge le serveur.
  List<Produit> get _visibles {
    final q = _recherche.text.trim().toLowerCase();
    if (q.isEmpty) return _produits;
    return _produits
        .where(
          (p) =>
              p.nom.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _supprimerProduit(Produit p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Supprimer ${p.nom} ?'),
        content: Text(
          [
            'Il ne sera plus proposé à la vente ni dans les ordonnances.',
            if (p.stockUnites > 0)
              'Son stock (${p.stockLabel}) sort et reste noté dans les mouvements.',
            'Les ventes passées gardent son nom.',
          ].join(' '),
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
      await _service.supprimerProduit(p.uuid);
      _dire('${p.nom} est supprimé.');
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _actionLot(String action, LotProduit l) async {
    switch (action) {
      case 'compter':
        return _inventaire(l);
      case 'corriger':
        return _corrigerLot(l);
      case 'retirer':
        final raison = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: Text(
              'Retirer le lot ${l.numero ?? 'sans numéro'} (${l.quantite} unité(s)) ?',
            ),
            children: [
              for (final r in [
                'Périmé',
                'Abîmé',
                'Perdu ou volé',
                'Rappel du fabricant',
              ])
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, r),
                  child: Text(r),
                ),
            ],
          ),
        );
        if (raison == null) return;
        await _faire(() => _service.retirerLot(l.uuid, raison));
      case 'annuler':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Annuler cette réception ?'),
            content: Text(
              'Le lot ${l.numero ?? 'sans numéro'} (${l.quantite} unité(s)) disparaît, comme s’il n’avait jamais été reçu.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Non'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Annuler la réception'),
              ),
            ],
          ),
        );
        if (ok == true) await _faire(() => _service.annulerReception(l.uuid));
    }
  }

  Future<void> _corrigerLot(LotProduit l) async {
    final numero = TextEditingController(text: l.numero ?? '');
    var peremption = DateTime.tryParse(l.peremption ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Corriger le lot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numero,
                decoration: const InputDecoration(labelText: 'Numéro de lot'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  peremption == null
                      ? 'Péremption inconnue'
                      : 'Périme le ${DateFormat('dd/MM/yyyy').format(peremption!)}',
                ),
                onTap: () async {
                  final choix = await showDatePicker(
                    context: ctx,
                    initialDate: peremption ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (choix != null) setD(() => peremption = choix);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _faire(
      () => _service.modifierLot(
        l.uuid,
        numero: numero.text.trim().isEmpty ? null : numero.text.trim(),
        peremption: peremption == null
            ? null
            : DateFormat('yyyy-MM-dd').format(peremption!),
      ),
    );
  }

  Future<void> _faire(Future<void> Function() action) async {
    try {
      await action();
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Future<void> _inventaire(LotProduit l) async {
    final ctrl = TextEditingController(text: '${l.quantite}');
    final n = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Lot ${l.numero ?? 'sans numéro'}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Unités comptées'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text)),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (n == null) return;
    try {
      await _service.inventorier(l.uuid, n);
      await _charger();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }
}

/// Les patients envoyés à la pharmacie : un toucher pour les servir.
class _AServir extends StatelessWidget {
  const _AServir({required this.patients, required this.onServir});

  final List<PatientAServir> patients;
  final ValueChanged<PatientAServir> onServir;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'À servir (${patients.length})',
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Card(
          child: Column(
            children: [
              for (final p in patients)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Kolors.kJauneDoux,
                    foregroundColor: Kolors.kPrimaryDark,
                    child: p.ticketCode == null
                        ? const Icon(Icons.receipt_long_rounded, size: 20)
                        : Text(
                            p.ticketCode!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  title: Text(
                    p.patient,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    p.ordonnances.isEmpty
                        ? 'Sans ordonnance : vente sur sa facture'
                        : [
                            for (final o in p.ordonnances)
                              for (final l in o.lignes.where(
                                (l) => l.reste > 0,
                              ))
                                '${l.produit} × ${l.reste}',
                          ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => onServir(p),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Alertes extends StatelessWidget {
  const _Alertes({required this.alertes});

  final Map<String, dynamic> alertes;

  /// Au-delà, « et N autres » : la liste ne doit pas cacher les produits.
  static const _visibles = 5;

  @override
  Widget build(BuildContext context) {
    List<Map> liste(String cle) => (alertes[cle] as List).cast<Map>();
    // Le plus grave d'abord : périmés, puis péremption proche, puis stock bas.
    final lignes = <(IconData, String, Color)>[
      for (final p in liste('perimes'))
        (
          Icons.block_rounded,
          '${p['medicament']} · lot ${p['lot'] ?? '—'} périmé (${p['quantite']})',
          Kolors.kRed,
        ),
      for (final p in liste('peremption_proche'))
        (
          Icons.hourglass_bottom_rounded,
          '${p['medicament']} · lot ${p['lot'] ?? '—'} périme le ${p['peremption']}',
          Kolors.kGold,
        ),
      for (final p in liste('stock_bas'))
        (
          Icons.trending_down_rounded,
          '${p['medicament']} : ${p['stock']} en stock (alerte sous ${p['seuil']})',
          Kolors.kTextHigh,
        ),
    ];
    return Card(
      color: Kolors.kJauneDoux,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'À surveiller',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            for (final l in lignes.take(_visibles))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(l.$1, size: 18, color: l.$3),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l.$2, style: TextStyle(color: l.$3)),
                    ),
                  ],
                ),
              ),
            if (lignes.length > _visibles)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'et ${lignes.length - _visibles} autre${lignes.length - _visibles > 1 ? 's' : ''}',
                  style: const TextStyle(
                    color: Kolors.kTextMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Créer ou modifier un produit.
/// Crée ou modifie un produit ; renvoie le produit enregistré. [avecStock] :
/// propose de saisir le stock déjà en rayon (pas depuis une réception, qui
/// le saisit elle-même).
/// « Marge : 450 F (30 %) » quand les deux prix sont saisis.
String? _marge(String achat, String vente, String devise) {
  final a = _montant(achat, devise);
  final v = _montant(vente, devise);
  if (a == null || v == null || a <= 0 || v <= 0) return null;
  final m = v - a;
  return 'Marge : ${m.toStringAsFixed(0)} F (${(m / v * 100).toStringAsFixed(0)} %)';
}

/// Un prix saisi (« 1500 », « 1.500 », « 1 500 ») en francs, cedis…
double? _montant(String saisi, String devise) {
  final m = lireMontant(saisi, devise);
  return m == null ? null : enMajeur(m, devise);
}

const _nouvelleCategorie = '__nouvelle__';

/// Demande le nom d'une catégorie, la crée, renvoie son code.
Future<String?> nouvelleCategorie(BuildContext context) async {
  final ctrl = TextEditingController();
  final nom = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nouvelle catégorie'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Nom (ex. Parapharmacie, Lunettes)',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            if (ctrl.text.trim().isNotEmpty) {
              Navigator.pop(ctx, ctrl.text.trim());
            }
          },
          child: const Text('Créer'),
        ),
      ],
    ),
  );
  if (nom == null) return null;
  try {
    return await Rayons.ajouter(nom);
  } on DioException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
    }
    return null;
  }
}

Future<Produit?> editerProduit(
  BuildContext context, [
  Produit? p,
  bool avecStock = true,
]) async {
  final nom = TextEditingController(text: p?.nom);
  final dci = TextEditingController(text: p?.dci);
  final forme = TextEditingController(text: p?.forme);
  final dosage = TextEditingController(text: p?.dosage);
  final cond = TextEditingController(text: '${p?.conditionnement ?? 1}');
  final prixBoite = TextEditingController(
    text: p == null ? '' : p.prixBoite.toStringAsFixed(0),
  );
  final prixUnite = TextEditingController(
    text: p?.prixUnite?.toStringAsFixed(0) ?? '',
  );
  final seuil = TextEditingController(text: '${p?.seuilAlerte ?? 5}');
  final codeBarres = TextEditingController(text: p?.codeBarres);
  final prixAchat = TextEditingController(
    text: p?.prixAchat?.toStringAsFixed(0) ?? '',
  );
  final devise = context.read<AuthController>().devise;
  var rayon = p?.rayon ?? 'medicaments';
  var venteUnite = p?.venteUnite ?? false;
  var ordonnance = p?.ordonnanceRequise ?? false;
  // Le stock en rayon : à la création, une première réception ; ensuite,
  // le compte corrigé (le serveur note l'écart).
  final boites = TextEditingController(
    text: p == null ? '' : '${p.stockBoites}',
  );
  final unitesEnPlus = TextEditingController(
    text: p == null
        ? ''
        : '${p.stockUnites - p.stockBoites * p.conditionnement}',
  );
  final lot = TextEditingController();
  DateTime? peremption;
  int parBoite() => int.tryParse(cond.text) ?? 1;

  final donnees = await formulaire<Map<String, dynamic>>(
    context,
    titre: Text(p == null ? 'Nouveau produit' : 'Modifier le produit'),
    corps: (ctx, setD) => Column(
      spacing: 12,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nom,
          decoration: const InputDecoration(
            labelText: 'Nom (ex. Doliprane 500 mg, Lait Guigoz 1er âge)',
          ),
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('rayon-$rayon-${rayons.length}'),
          initialValue: rayons.containsKey(rayon) ? rayon : null,
          decoration: const InputDecoration(labelText: 'Catégorie'),
          items: [
            for (final r in rayons.entries)
              DropdownMenuItem(value: r.key, child: Text(r.value)),
            const DropdownMenuItem(
              value: _nouvelleCategorie,
              child: Text('＋ Nouvelle catégorie…'),
            ),
          ],
          onChanged: (v) async {
            if (v != _nouvelleCategorie) {
              setD(() => rayon = v ?? rayon);
              return;
            }
            final code = await nouvelleCategorie(ctx);
            setD(() => rayon = code ?? rayon);
          },
        ),
        TextField(
          controller: codeBarres,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Code-barres (facultatif)',
            suffixIcon: IconButton(
              tooltip: 'Scanner le code-barres',
              icon: const Icon(Icons.qr_code_scanner_rounded),
              onPressed: () async {
                final lu = await scannerQr(
                  ctx,
                  titre: 'Code-barres',
                  consigne: 'Visez le code-barres de la boîte',
                );
                if (lu != null) setD(() => codeBarres.text = lu);
              },
            ),
          ),
        ),
        if (rayon == 'medicaments')
          TextField(
            controller: dci,
            decoration: const InputDecoration(labelText: 'Molécule (DCI)'),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: forme,
                decoration: const InputDecoration(labelText: 'Forme'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: dosage,
                decoration: const InputDecoration(labelText: 'Dosage'),
              ),
            ),
          ],
        ),
        TextField(
          controller: cond,
          keyboardType: TextInputType.number,
          onChanged: (_) => setD(() {}),
          decoration: const InputDecoration(
            labelText: 'Combien dans une boîte (comprimés, sachets…) ?',
            helperText:
                '1 si le produit se vend tel quel (savon, thermomètre).',
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: prixAchat,
                keyboardType: TextInputType.number,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(
                  labelText: 'Prix d’achat (boîte)',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: prixBoite,
                keyboardType: TextInputType.number,
                onChanged: (_) => setD(() {}),
                decoration: const InputDecoration(
                  labelText: 'Prix de vente (boîte)',
                ),
              ),
            ),
          ],
        ),
        if (_marge(prixAchat.text, prixBoite.text, devise) case final m?)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              m,
              style: const TextStyle(
                color: Kolors.kSuccess,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (p != null || avecStock) ...[
          const Divider(height: 24),
          Text(
            p == null ? 'Stock actuel (facultatif)' : 'En stock',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Text(
            p == null
                ? 'Ce que vous avez déjà en rayon. Ensuite, le stock bouge tout seul : réceptions, ventes, délivrances.'
                : 'Corrigez si votre compte en rayon est différent. Une livraison se saisit dans « Réception ».',
            style: const TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: boites,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    labelText: parBoite() > 1
                        ? 'Boîtes en stock'
                        : 'Quantité en stock',
                  ),
                ),
              ),
              if (p != null && parBoite() > 1) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: unitesEnPlus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Unités en plus (boîte ouverte)',
                    ),
                  ),
                ),
              ],
              if (p == null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: lot,
                    decoration: const InputDecoration(labelText: 'N° de lot'),
                  ),
                ),
              ],
            ],
          ),
          if (p == null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_busy_outlined),
              title: Text(
                peremption == null
                    ? 'Date de péremption'
                    : 'Périme le ${peremption!.day.toString().padLeft(2, '0')}/${peremption!.month.toString().padLeft(2, '0')}/${peremption!.year}',
              ),
              onTap: () async {
                final choix = await showDatePicker(
                  context: ctx,
                  initialDate: DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                  initialDatePickerMode: DatePickerMode.year,
                );
                if (choix != null) setD(() => peremption = choix);
              },
            ),
          const Divider(height: 24),
        ],
        // À l'unité : seulement s'il y a plusieurs unités dans la boîte.
        if (parBoite() > 1)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vendu aussi à l’unité'),
            value: venteUnite,
            onChanged: (v) => setD(() => venteUnite = v),
          ),
        if (venteUnite && parBoite() > 1)
          TextField(
            controller: prixUnite,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Prix à l’unité'),
          ),
        // « Sur ordonnance » ne concerne que les médicaments.
        if (rayon == 'medicaments')
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sur ordonnance seulement'),
            value: ordonnance,
            onChanged: (v) => setD(() => ordonnance = v),
          ),
        TextField(
          controller: seuil,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Alerte sous (unités)'),
        ),
      ],
    ),
    actions: (ctx, setD) => [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Annuler'),
      ),
      TextButton(
        onPressed: () {
          final prix = _montant(prixBoite.text, devise);
          if (nom.text.trim().isEmpty || prix == null) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('Indiquez le nom et le prix de la boîte.'),
              ),
            );
            return;
          }
          Navigator.pop(ctx, {
            'nom': nom.text.trim(),
            'dci': dci.text.trim(),
            'forme': forme.text.trim(),
            'dosage': dosage.text.trim(),
            'conditionnement': int.tryParse(cond.text) ?? 1,
            'prix_unitaire': prix,
            'vente_unite': venteUnite && parBoite() > 1,
            if (venteUnite && parBoite() > 1)
              'prix_unite': _montant(prixUnite.text, devise),
            'ordonnance_requise': rayon == 'medicaments' && ordonnance,
            'seuil_alerte': int.tryParse(seuil.text) ?? 5,
            'rayon': rayon,
            'code_barres': codeBarres.text.trim().isEmpty
                ? null
                : codeBarres.text.trim(),
            'prix_achat': _montant(prixAchat.text, devise),
          });
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );
  if (donnees == null || !context.mounted) return null;
  try {
    final service = PharmacieService();
    var produit = await service.enregistrerProduit(donnees, uuid: p?.uuid);
    final enStock = int.tryParse(boites.text) ?? 0;
    // Le compte corrigé à la main : le serveur ajoute ou retire l'écart.
    if (p != null && produit != null && boites.text.trim().isNotEmpty) {
      final compte =
          enStock * produit.conditionnement +
          // Les unités en plus ne valent que si la boîte n'a pas changé.
          (produit.conditionnement > 1 &&
                  produit.conditionnement == p.conditionnement
              ? int.tryParse(unitesEnPlus.text) ?? 0
              : 0);
      if (compte != produit.stockUnites) {
        produit = await service.compterStock(produit.uuid, compte) ?? produit;
      }
    }
    if (p == null && avecStock && enStock > 0 && produit != null) {
      await service.recevoir([
        {
          'medicament_uuid': produit.uuid,
          'boites': enStock,
          if (lot.text.trim().isNotEmpty) 'numero': lot.text.trim(),
          if (peremption != null)
            'peremption':
                '${peremption!.year}-${peremption!.month.toString().padLeft(2, '0')}-${peremption!.day.toString().padLeft(2, '0')}',
        },
      ]);
    }
    return produit;
  } on DioException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(messageErreur(e))));
    }
    return null;
  }
}

/// Réception d'une livraison : produit, lot, péremption, nombre de boîtes.
class ReceptionScreen extends StatefulWidget {
  const ReceptionScreen({required this.produits, super.key});

  final List<Produit> produits;

  @override
  State<ReceptionScreen> createState() => _ReceptionScreenState();
}

class _ReceptionScreenState extends State<ReceptionScreen> {
  final List<Map<String, dynamic>> _lignes = [];
  List<Map<String, dynamic>> _fournisseurs = [];
  // Tous les produits, pas seulement ceux affichés dans l'onglet (filtrés).
  late List<Produit> _produits = [...widget.produits];
  String? _fournisseur;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    PharmacieService()
        .produits()
        .then((p) {
          if (mounted) setState(() => _produits = p);
        })
        .catchError((_) {});
    PharmacieService()
        .fournisseurs()
        .then((f) {
          if (mounted) setState(() => _fournisseurs = f);
        })
        .catchError((_) {});
  }

  Future<void> _ajouterLigne() async {
    Produit? produit = _produits.firstOrNull;
    final numero = TextEditingController();
    final boites = TextEditingController(text: '1');
    DateTime? peremption;
    final ligne = await formulaire<Map<String, dynamic>>(
      context,
      titre: const Text('Ligne de livraison'),
      corps: (ctx, setD) => Column(
        spacing: 12,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_produits.isNotEmpty)
            DropdownButtonFormField<Produit>(
              // La clé change avec le produit choisi : un produit créé à
              // l'instant s'affiche tout de suite.
              key: ValueKey(produit?.uuid),
              initialValue: produit,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Produit'),
              items: [
                for (final p in _produits)
                  DropdownMenuItem(value: p, child: Text(p.nom)),
              ],
              onChanged: (v) => setD(() => produit = v),
            ),
          TextButton.icon(
            onPressed: () async {
              final nouveau = await editerProduit(ctx, null, false);
              if (nouveau == null) return;
              setState(() => _produits = [..._produits, nouveau]);
              setD(() => produit = nouveau);
            },
            icon: const Icon(Icons.add),
            label: Text(
              _produits.isEmpty
                  ? 'Créer le produit reçu'
                  : 'Produit absent de la liste ? Le créer',
            ),
          ),
          TextField(
            controller: numero,
            decoration: const InputDecoration(labelText: 'N° de lot'),
          ),
          TextField(
            controller: boites,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Boîtes reçues'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final d = await showDatePicker(
                context: ctx,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                initialDate: DateTime.now().add(const Duration(days: 365)),
                helpText: 'Date de péremption',
              );
              if (d != null) setD(() => peremption = d);
            },
            icon: const Icon(Icons.event_outlined),
            label: Text(
              peremption == null
                  ? 'Péremption'
                  : DateFormat('d/MM/yyyy').format(peremption!),
            ),
          ),
        ],
      ),
      actions: (ctx, setD) => [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            final n = int.tryParse(boites.text);
            if (produit == null || n == null || n <= 0) return;
            Navigator.pop(ctx, {
              'medicament_uuid': produit!.uuid,
              '_nom': produit!.nom,
              'numero': numero.text.trim(),
              if (peremption != null)
                'peremption': DateFormat('yyyy-MM-dd').format(peremption!),
              'boites': n,
            });
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
    if (ligne != null) setState(() => _lignes.add(ligne));
  }

  Future<void> _valider() async {
    setState(() => _envoi = true);
    try {
      await PharmacieService().recevoir([
        for (final l in _lignes) Map<String, dynamic>.from(l)..remove('_nom'),
      ], fournisseur: _fournisseur);
      if (mounted) Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Réception')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _fournisseur,
            decoration: const InputDecoration(labelText: 'Fournisseur'),
            items: [
              const DropdownMenuItem(value: null, child: Text('—')),
              for (final f in _fournisseurs)
                DropdownMenuItem(
                  value: f['uuid'].toString(),
                  child: Text(f['nom'].toString()),
                ),
            ],
            onChanged: (v) => setState(() => _fournisseur = v),
          ),
          TextButton.icon(
            onPressed: () async {
              final nom = TextEditingController();
              final n = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Nouveau fournisseur'),
                  content: TextField(
                    controller: nom,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom (ex. Laborex, Copharma)',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, nom.text.trim()),
                      child: const Text('Ajouter'),
                    ),
                  ],
                ),
              );
              if (n == null || n.isEmpty) return;
              await PharmacieService().creerFournisseur(n, null);
              final f = await PharmacieService().fournisseurs();
              if (mounted) setState(() => _fournisseurs = f);
            },
            icon: const Icon(Icons.add),
            label: const Text('Nouveau fournisseur'),
          ),
          const SizedBox(height: 8),
          for (final l in _lignes)
            Card(
              child: ListTile(
                title: Text(l['_nom'].toString()),
                subtitle: Text(
                  'Lot ${l['numero'] ?? '—'} · péremption ${l['peremption'] ?? '—'}',
                ),
                trailing: Text('${l['boites']} boîte(s)'),
              ),
            ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            onPressed: _ajouterLigne,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une ligne'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _lignes.isEmpty || _envoi ? null : _valider,
              child: const Text('Valider la réception'),
            ),
          ),
        ],
      ),
    );
  }
}
