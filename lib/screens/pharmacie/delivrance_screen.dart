import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../controllers/auth_controller.dart';
import '../../common/widgets/carte_marque.dart';
import '../../core/api/api_client.dart';
import '../../pharmacie/pharmacie_models.dart';
import '../../pharmacie/pharmacie_service.dart';
import '../caisse/visite_screen.dart';
import '../../common/widgets/feuille.dart';

/// Délivrer : sur ordonnance (chaque ligne prescrite, jamais au-delà de ce
/// qui reste), ou au comptoir. La délivrance facture sur la visite ; la
/// caisse encaisse ensuite.
class DelivranceScreen extends StatefulWidget {
  const DelivranceScreen({
    this.ordonnance,
    this.visiteUuid,
    this.horsLigne = false,
    super.key,
  });

  final OrdonnanceRx? ordonnance;

  /// La visite du patient qui attend : la délivrance s'ajoute à sa facture.
  final String? visiteUuid;

  /// Ordonnance vérifiée sans internet : on montre, on ne délivre pas.
  final bool horsLigne;

  @override
  State<DelivranceScreen> createState() => _DelivranceScreenState();
}

class _Ligne {
  _Ligne({
    this.prescrite,
    this.produit,
    this.quantite = 1,
    this.unite = 'boite',
  });

  final LigneOrdonnance? prescrite;
  Produit? produit;
  int quantite;
  String unite;
}

class _DelivranceScreenState extends State<DelivranceScreen> {
  final _service = PharmacieService();
  List<Produit> _produits = [];
  final List<_Ligne> _lignes = [];
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    if (widget.horsLigne) return;
    try {
      _produits = await _service.produits();
    } on DioException catch (e) {
      _dire(messageErreur(e));
    }
    final o = widget.ordonnance;
    if (o != null) {
      for (final l in o.lignes.where((l) => l.reste > 0)) {
        final produit = _trouver(l);
        final unite = produit?.venteUnite == true ? 'unite' : 'boite';
        final quantite = unite == 'unite'
            ? l.reste
            : (l.reste / (produit?.conditionnement ?? 1))
                  .ceil()
                  .clamp(1, 9999)
                  .toInt();
        _lignes.add(
          _Ligne(
            prescrite: l,
            produit: produit,
            quantite: quantite,
            unite: unite,
          ),
        );
      }
    }
    if (mounted) setState(() {});
  }

  /// Le produit du stock qui correspond à la ligne prescrite.
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

  void _dire(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<Produit?> _choisirProduit() {
    return feuille<Produit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChoixProduit(produits: _produits),
    );
  }

  Future<void> _delivrer() async {
    final pretes = _lignes
        .where((l) => l.produit != null && l.quantite > 0)
        .toList();
    if (pretes.isEmpty) return;
    setState(() => _envoi = true);
    try {
      final visite = await _service.delivrer(
        [
          for (final l in pretes)
            {
              'medicament_uuid': l.produit!.uuid,
              'quantite': l.quantite,
              'unite': l.unite,
              'ordonnance_ligne_uuid': ?l.prescrite?.uuid,
            },
        ],
        ordonnance: widget.ordonnance?.uuid,
        visite: widget.visiteUuid,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VisiteScreen(uuid: visite.uuid)),
      );
    } on DioException catch (e) {
      _dire(messageErreur(e));
      if (mounted) setState(() => _envoi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.ordonnance;
    return Scaffold(
      appBar: AppBar(
        title: Text(o == null ? 'Vente au comptoir' : 'Ordonnance'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (o != null)
            CarteMarque(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_rounded, color: Kolors.kJaune),
                      const SizedBox(width: 8),
                      Text(
                        widget.horsLigne
                            ? 'Authentique (vérifiée sans internet)'
                            : 'Authentique',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    o.patientNom,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      if (o.prescripteur != null) o.prescripteur!,
                      o.etablissement,
                      if (o.date != null) o.date!,
                    ].join(' · '),
                    style: TextStyle(
                      color: Kolors.kWhite.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    o.statutLabel,
                    style: const TextStyle(
                      color: Kolors.kJaune,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          if (o != null && widget.horsLigne) ...[
            const SizedBox(height: 12),
            for (final l in o.lignes)
              Card(
                child: ListTile(
                  title: Text(l.produit),
                  subtitle: l.posologie == null ? null : Text(l.posologie!),
                  trailing: Text('${l.quantite}'),
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Sans internet, on ne voit pas ce qui a déjà été délivré ailleurs : reconnectez-vous pour délivrer.',
                style: TextStyle(color: Kolors.kGold),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            if (o != null && _lignes.isEmpty && _produits.isNotEmpty)
              const Text(
                'Tout a déjà été délivré.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            for (final l in _lignes) _carteLigne(l),
            if (o == null)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () async {
                  final p = await _choisirProduit();
                  if (p != null) {
                    setState(() => _lignes.add(_Ligne(produit: p)));
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un produit'),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Kolors.kJaune,
                  foregroundColor: Kolors.kPrimaryDark,
                ),
                onPressed: _envoi || _lignes.every((l) => l.produit == null)
                    ? null
                    : _delivrer,
                icon: const Icon(Icons.local_pharmacy_rounded),
                label: const Text('Délivrer et facturer'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _carteLigne(_Ligne l) {
    final p = l.produit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (l.prescrite != null) ...[
              Text(
                'Prescrit : ${l.prescrite!.produit}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                [
                  if (l.prescrite!.posologie != null) l.prescrite!.posologie!,
                  'reste ${l.prescrite!.reste} unité(s)',
                ].join(' · '),
                style: const TextStyle(color: Kolors.kTextMuted),
              ),
              const SizedBox(height: 8),
            ],
            InkWell(
              onTap: () async {
                final choix = await _choisirProduit();
                if (choix != null) {
                  setState(() {
                    l.produit = choix;
                    if (!choix.venteUnite) l.unite = 'boite';
                  });
                }
              },
              child: Row(
                children: [
                  const Icon(Icons.medication_rounded, color: Kolors.kPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p == null
                          ? 'Choisir le produit en stock'
                          : '${p.nom} · ${p.stockLabel}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: p == null ? Kolors.kRed : Kolors.kTextHigh,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.swap_horiz_rounded,
                    color: Kolors.kTextMuted,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: l.quantite > 1
                      ? () => setState(() => l.quantite--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '${l.quantite}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => l.quantite++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
                const SizedBox(width: 8),
                if (p != null && p.venteUnite)
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'boite', label: Text('Boîte')),
                      ButtonSegment(value: 'unite', label: Text('Unité')),
                    ],
                    selected: {l.unite},
                    onSelectionChanged: (s) =>
                        setState(() => l.unite = s.first),
                  )
                else
                  const Text('boîte(s)'),
                const Spacer(),
                if (l.prescrite == null)
                  IconButton(
                    onPressed: () => setState(() => _lignes.remove(l)),
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Choisir un produit de la pharmacie : nom ou molécule, avec prix et stock.
class ChoixProduit extends StatefulWidget {
  const ChoixProduit({required this.produits, super.key});

  final List<Produit> produits;

  @override
  State<ChoixProduit> createState() => ChoixProduitState();
}

class ChoixProduitState extends State<ChoixProduit> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final liste = widget.produits
        .where(
          (p) =>
              p.nom.toLowerCase().contains(q) ||
              (p.dci ?? '').toLowerCase().contains(q),
        )
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Nom ou molécule (DCI)',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final p in liste)
                  ListTile(
                    title: Text(p.nom),
                    subtitle: Text(
                      [
                        p.description,
                        prixProduit(p, context.read<AuthController>().devise),
                        p.stockLabel,
                      ].where((s) => s.isNotEmpty).join(' · '),
                    ),
                    trailing: p.stockUnites == 0
                        ? const Text(
                            'Rupture',
                            style: TextStyle(color: Kolors.kRed),
                          )
                        : null,
                    onTap: () => Navigator.pop(context, p),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « 1 500 FCFA la boîte de 10 · 200 FCFA l'unité ».
String prixProduit(Produit p, String devise) {
  String m(double v) => formatMontant(lireMontant('$v', devise) ?? 0, devise);
  return [
    p.conditionnement > 1
        ? '${m(p.prixBoite)} la boîte de ${p.conditionnement}'
        : m(p.prixBoite),
    if (p.venteUnite && p.prixUnite != null) "${m(p.prixUnite!)} l'unité",
  ].join(' · ');
}

/// Le prix de [unites] unités prescrites : à l'unité si elle se vend ainsi,
/// sinon en boîtes entières.
double prixPrescrit(Produit p, int unites) =>
    p.venteUnite && p.prixUnite != null
    ? p.prixUnite! * unites
    : p.prixBoite *
          (unites / (p.conditionnement < 1 ? 1 : p.conditionnement)).ceil();
