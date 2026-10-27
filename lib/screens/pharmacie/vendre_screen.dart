import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../caisse/caisse_service.dart';
import '../../common/utils/kcolors.dart';
import '../../common/whatsapp.dart';
import '../../common/widgets/feuille.dart';
import '../../controllers/auth_controller.dart';
import '../../core/api/api_client.dart';
import '../../pharmacie/pharmacie_models.dart';
import '../../pharmacie/pharmacie_service.dart';
import '../../pharmacie/recu.dart';
import '../commun/scanner_qr_screen.dart';
import '../file/ticket_carte.dart';
import 'pharmacie_tab.dart';

/// Vendre, comme à la caisse d'une boutique : on tape un nom ou on scanne
/// le code-barres, le produit tombe dans le panier ; on encaisse en un geste
/// (ou le client passe au caissier) ; un reçu à imprimer ou à envoyer.
/// L'ordonnance d'un établissement Ngoni Santé se scanne ici aussi : ses
/// produits arrivent dans le panier.
class VendreScreen extends StatefulWidget {
  /// [onglet] : premier onglet d'une officine (sans barre de titre).
  const VendreScreen({this.onglet = false, super.key});

  final bool onglet;

  @override
  State<VendreScreen> createState() => _VendreScreenState();
}

class _Article {
  _Article(
    this.produit, {
    this.quantite = 1,
    this.unite = 'boite',
    this.prescrite,
  });

  final Produit produit;
  int quantite;
  String unite;
  final LigneOrdonnance? prescrite;

  double get prix =>
      unite == 'unite' ? (produit.prixUnite ?? 0) : produit.prixBoite;
  double get montant => prix * quantite;
  int get unites =>
      unite == 'unite' ? quantite : quantite * produit.conditionnement;
}

class _VendreScreenState extends State<VendreScreen> {
  final _service = PharmacieService();
  final _recherche = TextEditingController();
  final _client = TextEditingController();
  final _telephone = TextEditingController();
  List<Produit> _produits = [];
  List<String> _moyens = const ['especes'];
  final List<_Article> _panier = [];
  OrdonnanceRx? _ordonnance;
  String? _rayon;
  bool _chargement = true;
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _recherche.dispose();
    _client.dispose();
    _telephone.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    final auth = context.read<AuthController>();
    try {
      _produits = await _service.produits();
      if (auth.peut('caisse.encaisser')) {
        final s = await CaisseService().session();
        if (s['moyens'] is List) {
          _moyens = [for (final m in s['moyens'] as List) m.toString()];
        }
      }
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

  String _f(double v) {
    final devise = context.read<AuthController>().devise;
    return formatMontant(lireMontant('$v', devise) ?? 0, devise);
  }

  double get _total => _panier.fold(0, (s, a) => s + a.montant);

  /// Le produit tombe dans le panier (ou une boîte de plus s'il y est déjà).
  void _ajouter(Produit p) {
    if (p.stockUnites <= 0) {
      _dire('${p.nom} : rupture de stock.');
      return;
    }
    setState(() {
      final deja = _panier.where((a) => a.produit.uuid == p.uuid).firstOrNull;
      if (deja != null) {
        deja.quantite++;
      } else {
        _panier.add(_Article(p));
      }
    });
    HapticFeedback.selectionClick();
  }

  /// Le code-barres lu (douchette ou caméra) : le produit qui le porte.
  void _parCode(String code) {
    final p = _produits.where((x) => x.codeBarres == code.trim()).firstOrNull;
    if (p == null) {
      _dire('Code $code inconnu : ajoutez-le au produit (Stock › le produit).');
      return;
    }
    _recherche.clear();
    _ajouter(p);
  }

  Future<void> _scannerCode() async {
    final code = await scannerQr(
      context,
      titre: 'Code-barres',
      consigne: 'Visez le code-barres de la boîte',
    );
    if (code != null) _parCode(code);
  }

  /// L'ordonnance d'un établissement Ngoni Santé : ses produits dans le panier.
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
      final manquants = <String>[];
      setState(() {
        _ordonnance = o;
        if (_client.text.trim().isEmpty) _client.text = o.patientNom;
        for (final l in o.lignes.where((l) => l.reste > 0)) {
          final p = _trouver(l);
          if (p == null || p.stockUnites <= 0) {
            manquants.add(l.produit);
            continue;
          }
          final unite = p.venteUnite && p.prixUnite != null ? 'unite' : 'boite';
          final quantite = unite == 'unite'
              ? l.reste
              : (l.reste / p.conditionnement).ceil().clamp(1, 9999).toInt();
          _panier.removeWhere((a) => a.produit.uuid == p.uuid);
          _panier.add(
            _Article(p, quantite: quantite, unite: unite, prescrite: l),
          );
        }
      });
      if (manquants.isNotEmpty) {
        _dire('Pas en stock ici : ${manquants.join(', ')}.');
      }
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
  }

  Produit? _trouver(LigneOrdonnance l) {
    final parUuid = _produits
        .where((p) => p.uuid == l.medicamentUuid)
        .firstOrNull;
    if (parUuid != null) return parUuid;
    final mot = l.produit.toLowerCase().split(' ').first;
    return _produits
        .where(
          (p) =>
              p.nom.toLowerCase().contains(mot) ||
              (p.dci ?? '').toLowerCase().contains(mot),
        )
        .firstOrNull;
  }

  void _vider() => setState(() {
    _panier.clear();
    _ordonnance = null;
    _client.clear();
    _telephone.clear();
  });

  List<Map<String, dynamic>> get _lignes => [
    for (final a in _panier)
      {
        'medicament_uuid': a.produit.uuid,
        'quantite': a.quantite,
        'unite': a.unite,
        if (a.prescrite != null && a.prescrite!.uuid.isNotEmpty)
          'ordonnance_ligne_uuid': a.prescrite!.uuid,
      },
  ];

  /// Encaisser : le moyen de paiement, la monnaie à rendre, puis la vente.
  Future<void> _encaisser() async {
    final paiement = await feuille<(String, String?)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _Paiement(total: _total, moyens: _moyens, format: _f),
    );
    if (paiement == null) return;
    await _vendre(moyen: paiement.$1, reference: paiement.$2);
  }

  Future<void> _vendre({String? moyen, String? reference}) async {
    if (_panier.isEmpty || _envoi) return;
    setState(() => _envoi = true);
    try {
      final vente = await _service.vendre(
        _lignes,
        ordonnance: _ordonnance?.uuid,
        client: _client.text.trim().isEmpty ? null : _client.text.trim(),
        telephone: _telephone.text.trim().isEmpty
            ? null
            : _telephone.text.trim(),
        moyen: moyen,
        reference: reference,
      );
      if (!mounted) return;
      _vider();
      // Le stock a bougé : la liste se relit derrière le reçu.
      _service.produits().then((l) {
        if (mounted) setState(() => _produits = l);
      });
      await afficherRecu(context, vente);
    } on DioException catch (e) {
      _dire(messageErreur(e));
    } finally {
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.sizeOf(context).width >= 900;
    final corps = _chargement
        ? const Center(child: CircularProgressIndicator())
        : large
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _catalogue()),
              SizedBox(
                width: 400,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                  child: Card(margin: EdgeInsets.zero, child: _panierVue()),
                ),
              ),
            ],
          )
        : Column(
            children: [
              Expanded(child: _catalogue()),
              _barrePanier(),
            ],
          );
    if (widget.onglet) return corps;
    return Scaffold(
      appBar: AppBar(title: const Text('Vendre')),
      body: corps,
    );
  }

  // ------------------------------------------------------------ catalogue

  Widget _catalogue() {
    final q = _recherche.text.trim().toLowerCase();
    final presents = {for (final p in _produits) p.rayon};
    final liste = q.isNotEmpty
        ? _produits
              .where(
                (p) =>
                    p.nom.toLowerCase().contains(q) ||
                    (p.dci ?? '').toLowerCase().contains(q) ||
                    p.codeBarres == q,
              )
              .toList()
        : _rayon == null
        ? ([..._produits]..sort((a, b) {
                final v = b.ventes.compareTo(a.ventes);
                return v != 0 ? v : a.nom.compareTo(b.nom);
              }))
              .take(30)
              .toList()
        : _produits.where((p) => p.rayon == _rayon).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _recherche,
                autofocus: widget.onglet,
                onChanged: (_) => setState(() {}),
                // Une douchette tape le code puis « Entrée ».
                onSubmitted: (v) {
                  if (RegExp(r'^\d{6,}$').hasMatch(v.trim())) {
                    _parCode(v);
                  } else if (liste.length == 1) {
                    _recherche.clear();
                    _ajouter(liste.first);
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Nom, molécule ou code-barres',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Scanner un code-barres',
              onPressed: _scannerCode,
              icon: const Icon(Icons.barcode_reader),
            ),
            const SizedBox(width: 4),
            IconButton.filledTonal(
              tooltip: 'Scanner une ordonnance',
              onPressed: _scannerOrdonnance,
              icon: const Icon(Icons.qr_code_scanner_rounded),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Les rayons sur une ligne qui défile : la grille reste visible.
        if (q.isEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Plus vendus'),
                  selected: _rayon == null,
                  onSelected: (_) => setState(() => _rayon = null),
                ),
                for (final r in rayons.entries)
                  if (presents.contains(r.key))
                    ChoiceChip(
                      label: Text(r.value),
                      selected: _rayon == r.key,
                      onSelected: (_) => setState(() => _rayon = r.key),
                    ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (_produits.isEmpty)
          _Vide(
            onAjouter: () async {
              await editerProduit(context);
              _charger();
            },
          )
        else if (liste.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              'Aucun produit ne correspond.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Kolors.kTextMuted),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, c) {
              final colonnes = (c.maxWidth / 190).floor().clamp(2, 6);
              final largeur = (c.maxWidth - 10 * (colonnes - 1)) / colonnes;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in liste)
                    SizedBox(
                      width: largeur,
                      child: _TuileProduit(
                        produit: p,
                        prix: _f(p.prixBoite),
                        dansPanier: _panier
                            .where((a) => a.produit.uuid == p.uuid)
                            .fold(0, (s, a) => s + a.quantite),
                        onTap: () => _ajouter(p),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  // ------------------------------------------------------------ panier

  /// Au téléphone : le panier en bas, qui s'ouvre d'un toucher.
  Widget _barrePanier() {
    final n = _panier.fold(0, (s, a) => s + a.quantite);
    return Material(
      color: Kolors.kPrimary,
      child: SafeArea(
        top: false,
        child: InkWell(
          onTap: _panier.isEmpty
              ? null
              : () async {
                  await feuille<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx, setFeuille) => SizedBox(
                        height: MediaQuery.sizeOf(ctx).height * 0.85,
                        child: _panierVue(
                          rafraichir: () => setFeuille(() {}),
                          fermer: () => Navigator.pop(ctx),
                        ),
                      ),
                    ),
                  );
                  if (mounted) setState(() {});
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                const Icon(Icons.shopping_basket_rounded, color: Kolors.kJaune),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _panier.isEmpty
                        ? 'Panier vide'
                        : '$n article${n > 1 ? 's' : ''} · ${_f(_total)}',
                    style: const TextStyle(
                      color: Kolors.kWhite,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (_panier.isNotEmpty)
                  const Text(
                    'Voir le panier',
                    style: TextStyle(
                      color: Kolors.kJaune,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panierVue({VoidCallback? rafraichir, VoidCallback? fermer}) {
    final auth = context.watch<AuthController>();
    void maj(VoidCallback f) {
      setState(f);
      rafraichir?.call();
    }

    final encaisseIci = auth.peut('caisse.encaisser') && !auth.caisseSeparee;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Row(
            children: [
              Text(
                'Panier',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (_panier.isNotEmpty)
                TextButton(
                  onPressed: () => maj(_vider),
                  child: const Text('Vider'),
                ),
            ],
          ),
        ),
        if (_ordonnance != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              color: Kolors.kJauneDoux,
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.verified_rounded,
                  color: Kolors.kPrimary,
                ),
                title: Text('Ordonnance de ${_ordonnance!.patientNom}'),
                subtitle: Text(
                  [
                    ?_ordonnance!.prescripteur,
                    _ordonnance!.etablissement,
                  ].join(' · '),
                ),
              ),
            ),
          ),
        Expanded(
          child: _panier.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Touchez un produit, tapez son nom ou scannez son code-barres.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Kolors.kTextMuted),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final a in _panier)
                      _LignePanier(
                        article: a,
                        format: _f,
                        onChange: () => maj(() {}),
                        onRetirer: () => maj(() => _panier.remove(a)),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _client,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Client (facultatif)',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _telephone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Téléphone (reçu)',
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    _f(_total),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Kolors.kPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Kolors.kJaune,
                    foregroundColor: Kolors.kPrimaryDark,
                  ),
                  onPressed: _panier.isEmpty || _envoi
                      ? null
                      : () async {
                          fermer?.call();
                          encaisseIci ? await _encaisser() : await _vendre();
                        },
                  icon: Icon(
                    encaisseIci
                        ? Icons.payments_rounded
                        : Icons.point_of_sale_rounded,
                  ),
                  label: Text(
                    encaisseIci
                        ? 'Encaisser ${_f(_total)}'
                        : 'Envoyer à la caisse',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TuileProduit extends StatelessWidget {
  const _TuileProduit({
    required this.produit,
    required this.prix,
    required this.dansPanier,
    required this.onTap,
  });

  final Produit produit;
  final String prix;
  final int dansPanier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rupture = produit.stockUnites <= 0;
    return Material(
      color: rupture ? Kolors.kSecondaryLight : Kolors.kWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: dansPanier > 0 ? Kolors.kJaune : Kolors.kSecondaryLight,
          width: dansPanier > 0 ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: rupture ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      produit.nom,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (dansPanier > 0)
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Kolors.kJaune,
                      child: Text(
                        '$dansPanier',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Kolors.kPrimaryDark,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                prix,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Kolors.kPrimary,
                ),
              ),
              Text(
                rupture
                    ? 'Rupture'
                    : (produit.conditionnement > 1
                          ? '${produit.stockBoites} boîte(s)'
                          : '${produit.stockUnites} en stock'),
                style: TextStyle(
                  fontSize: 12,
                  color: rupture ? Kolors.kRed : Kolors.kTextMuted,
                  fontWeight: rupture ? FontWeight.w700 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LignePanier extends StatelessWidget {
  const _LignePanier({
    required this.article,
    required this.format,
    required this.onChange,
    required this.onRetirer,
  });

  final _Article article;
  final String Function(double) format;
  final VoidCallback onChange;
  final VoidCallback onRetirer;

  @override
  Widget build(BuildContext context) {
    final a = article;
    final p = a.produit;
    final trop = a.unites > p.stockUnites;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.nom,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                format(a.montant),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (a.prescrite != null)
            Text(
              'Prescrit : ${a.prescrite!.reste}${a.prescrite!.posologie == null ? '' : ' · ${a.prescrite!.posologie}'}',
              style: const TextStyle(fontSize: 12, color: Kolors.kTextMuted),
            ),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  if (a.quantite > 1) {
                    a.quantite--;
                    onChange();
                  } else {
                    onRetirer();
                  }
                },
                icon: Icon(
                  a.quantite > 1
                      ? Icons.remove_circle_outline
                      : Icons.delete_outline,
                ),
              ),
              Text(
                '${a.quantite}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  a.quantite++;
                  onChange();
                },
                icon: const Icon(Icons.add_circle_outline),
              ),
              const SizedBox(width: 6),
              // À la boîte, ou à l'unité (plaquette, comprimé, sachet) si le produit le permet.
              if (p.venteUnite && p.prixUnite != null)
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    const ButtonSegment(value: 'boite', label: Text('Boîte')),
                    ButtonSegment(
                      value: 'unite',
                      label: Text(
                        p.forme?.isNotEmpty == true ? p.forme! : 'Unité',
                      ),
                    ),
                  ],
                  selected: {a.unite},
                  onSelectionChanged: (s) {
                    a.unite = s.first;
                    onChange();
                  },
                )
              else
                Text(
                  p.conditionnement > 1 ? 'boîte(s)' : '',
                  style: const TextStyle(color: Kolors.kTextMuted),
                ),
            ],
          ),
          if (trop)
            Text(
              'Il n’en reste que ${p.stockUnites} unité(s).',
              style: const TextStyle(
                color: Kolors.kRed,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          const Divider(height: 8),
        ],
      ),
    );
  }
}

/// Le paiement : le moyen ; en espèces, la somme reçue et la monnaie à
/// rendre ; en Mobile Money, la référence de la transaction.
class _Paiement extends StatefulWidget {
  const _Paiement({
    required this.total,
    required this.moyens,
    required this.format,
  });

  final double total;
  final List<String> moyens;
  final String Function(double) format;

  @override
  State<_Paiement> createState() => _PaiementState();
}

class _PaiementState extends State<_Paiement> {
  late String _moyen = widget.moyens.first;
  final _recu = TextEditingController();
  final _reference = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final recu = double.tryParse(
      _recu.text.replaceAll(' ', '').replaceAll(',', '.'),
    );
    final rendu = recu == null ? null : recu - widget.total;
    final especes = _moyen == 'especes';
    final pret = especes
        ? (rendu == null || rendu >= 0)
        : _reference.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Encaisser ${widget.format(widget.total)}',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in widget.moyens)
                ChoiceChip(
                  label: Text(libellesMoyens[m] ?? m),
                  selected: _moyen == m,
                  onSelected: (_) => setState(() => _moyen = m),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (especes) ...[
            TextField(
              controller: _recu,
              autofocus: true,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Somme reçue (facultatif)',
              ),
            ),
            if (rendu != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  rendu >= 0
                      ? 'À rendre : ${widget.format(rendu)}'
                      : 'Il manque ${widget.format(-rendu)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: rendu >= 0 ? Kolors.kSuccess : Kolors.kRed,
                  ),
                ),
              ),
          ] else
            TextField(
              controller: _reference,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Référence de la transaction',
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: pret
                  ? () => Navigator.pop(context, (
                      _moyen,
                      especes ? null : _reference.text.trim(),
                    ))
                  : null,
              child: const Text('Valider la vente'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.onAjouter});

  final VoidCallback onAjouter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 56,
            color: Kolors.kTextMuted,
          ),
          const SizedBox(height: 8),
          const Text(
            'Aucun produit. Ajoutez ce que vous vendez : médicaments, préservatifs, lait, savons…',
            textAlign: TextAlign.center,
            style: TextStyle(color: Kolors.kTextMuted),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onAjouter,
            icon: const Icon(Icons.add_box_outlined),
            label: const Text('Ajouter un produit'),
          ),
        ],
      ),
    );
  }
}

/// Le reçu après la vente : imprimer, envoyer par WhatsApp, ou passer au
/// client suivant.
Future<void> afficherRecu(BuildContext context, Vente v) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(
        v.payee ? Icons.check_circle_rounded : Icons.point_of_sale_rounded,
        color: v.payee ? Kolors.kSuccess : Kolors.kGold,
        size: 48,
      ),
      title: Text(v.payee ? 'Vente encaissée' : 'Le client paie à la caisse'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatMontant(v.total, v.devise),
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            'Reçu N° ${v.numero}${v.client.isEmpty ? '' : ' · ${v.client}'}',
            style: const TextStyle(color: Kolors.kTextMuted),
          ),
          if (!v.payee)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Remettez les produits une fois la vente payée.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      actions: [
        if (v.telephone != null && v.telephone!.isNotEmpty)
          TextButton.icon(
            onPressed: () => envoyerWhatsApp(ctx, v.telephone!, Recu.texte(v)),
            icon: const Icon(Icons.chat_outlined),
            label: const Text('WhatsApp'),
          ),
        TextButton.icon(
          onPressed: () => imprimerSurThermique(ctx, () => Recu.octets(v)),
          icon: const Icon(Icons.print_outlined),
          label: const Text('Imprimer'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Client suivant'),
        ),
      ],
    ),
  );
}
