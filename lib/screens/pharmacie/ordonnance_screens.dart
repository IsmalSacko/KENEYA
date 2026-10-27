import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../caisse/caisse_models.dart';
import '../../common/utils/kcolors.dart';
import '../../common/widgets/feuille.dart';
import '../../controllers/auth_controller.dart';
import '../../common/widgets/carte_marque.dart';
import '../../compte/compte_api.dart';
import '../../core/api/api_client.dart';
import '../../pharmacie/pharmacie_models.dart';
import '../../pharmacie/pharmacie_service.dart';
import 'delivrance_screen.dart';

/// Le médecin prescrit : produit (pris dans la pharmacie de l'établissement,
/// avec son prix et son stock, ou écrit librement), posologie, quantité.
/// L'ordonnance est signée ; son QR se délivre dans n'importe quelle
/// pharmacie Ngoni Santé. Le prix va sur la facture quand la pharmacie
/// délivre : on ne paie que ce qu'on emporte.
class PrescrireScreen extends StatefulWidget {
  const PrescrireScreen({this.visiteUuid, this.patient, super.key});

  final String? visiteUuid;
  final String? patient;

  @override
  State<PrescrireScreen> createState() => _PrescrireScreenState();
}

class _LignePrescrite {
  final produit = TextEditingController();

  /// Le produit de la pharmacie, s'il a été choisi dans la liste.
  Produit? choisi;
  final posologie = TextEditingController();
  final quantite = TextEditingController(text: '1');
}

class _PrescrireScreenState extends State<PrescrireScreen> {
  late final _patient = TextEditingController(text: widget.patient);
  final List<_LignePrescrite> _lignes = [_LignePrescrite()];
  List<Produit> _catalogue = [];
  bool _envoi = false;

  @override
  void initState() {
    super.initState();
    // Sans pharmacie (ou sans droit), on écrit le produit librement.
    PharmacieService()
        .produits()
        .then((l) {
          if (mounted) setState(() => _catalogue = l);
        })
        .catchError((Object _) {});
  }

  Future<void> _choisir(_LignePrescrite l) async {
    final p = await feuille<Produit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChoixProduit(produits: _catalogue),
    );
    if (p == null) return;
    setState(() {
      l.choisi = p;
      l.produit.text = p.nom;
      if ((int.tryParse(l.quantite.text) ?? 0) <= 1 && p.conditionnement > 1) {
        l.quantite.text = '${p.conditionnement}';
      }
    });
  }

  /// Ce que le patient paiera à la pharmacie, si tout est délivré ici.
  double get _total => [
    for (final l in _lignes)
      if (l.choisi != null)
        prixPrescrit(l.choisi!, int.tryParse(l.quantite.text) ?? 0),
  ].fold(0, (a, b) => a + b);

  Future<void> _valider() async {
    final lignes = [
      for (final l in _lignes)
        if (l.produit.text.trim().isNotEmpty &&
            (int.tryParse(l.quantite.text) ?? 0) > 0)
          {
            'produit': l.produit.text.trim(),
            'posologie': l.posologie.text.trim(),
            'quantite': int.parse(l.quantite.text),
            'medicament_uuid': ?l.choisi?.uuid,
          },
    ];
    if (lignes.isEmpty) return;
    setState(() => _envoi = true);
    try {
      final o = await PharmacieService().prescrire(
        lignes,
        visite: widget.visiteUuid,
        patient: widget.visiteUuid == null ? _patient.text.trim() : null,
      );
      if (!mounted) return;
      await afficherOrdonnance(context, o);
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
    final devise = context.read<AuthController>().devise;
    final total = _total;
    return Scaffold(
      appBar: AppBar(title: const Text('Ordonnance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.visiteUuid == null)
            TextField(
              controller: _patient,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Patient'),
            )
          else
            Text(
              widget.patient ?? '',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < _lignes.length; i++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: _lignes[i].produit,
                      // Écrit à la main : ce n'est plus le produit choisi.
                      onChanged: (v) {
                        if (_lignes[i].choisi?.nom != v) {
                          setState(() => _lignes[i].choisi = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Produit ${i + 1} (ex. Paracétamol 500 mg)',
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_catalogue.isNotEmpty)
                              IconButton(
                                tooltip: 'Choisir dans la pharmacie',
                                icon: const Icon(Icons.medication_outlined),
                                onPressed: () => _choisir(_lignes[i]),
                              ),
                            if (_lignes.length > 1)
                              IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () =>
                                    setState(() => _lignes.removeAt(i)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (_lignes[i].choisi case final p?)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            p.stockUnites == 0
                                ? '${prixProduit(p, devise)} · rupture : à acheter ailleurs'
                                : '${prixProduit(p, devise)} · ${p.stockLabel}',
                            style: TextStyle(
                              fontSize: 13,
                              color: p.stockUnites == 0
                                  ? Kolors.kRed
                                  : Kolors.kTextMuted,
                            ),
                          ),
                        ),
                      ),
                    TextField(
                      controller: _lignes[i].posologie,
                      decoration: const InputDecoration(
                        labelText:
                            'Posologie (ex. 1 cp matin et soir, 5 jours)',
                      ),
                    ),
                    TextField(
                      controller: _lignes[i].quantite,
                      onChanged: (_) => setState(() {}),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Quantité (unités : comprimés, flacons…)',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _lignes.add(_LignePrescrite())),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un produit'),
          ),
          if (total > 0) ...[
            const SizedBox(height: 16),
            Text(
              'Total prévu à la pharmacie : ${formatMontant(lireMontant('$total', devise) ?? 0, devise)}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'Il s’ajoute à la facture quand la pharmacie délivre.',
              style: TextStyle(color: Kolors.kTextMuted),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _envoi ? null : _valider,
              child: const Text('Signer l’ordonnance'),
            ),
          ),
        ],
      ),
    );
  }
}

/// L'ordonnance et son QR, à montrer à la pharmacie.
Future<void> afficherOrdonnance(BuildContext context, OrdonnanceRx o) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
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
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Kolors.kWhite.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final l in o.lignes)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${l.produit} — ${l.quantite}${l.posologie == null || l.posologie!.isEmpty ? '' : ' · ${l.posologie}'}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Kolors.kWhite,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: QrImageView(data: o.qr, size: 220),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${o.statutLabel} · à montrer à la pharmacie',
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
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fermer'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Les ordonnances de la personne, avec leur QR.
class MesOrdonnancesScreen extends StatefulWidget {
  const MesOrdonnancesScreen({super.key});

  @override
  State<MesOrdonnancesScreen> createState() => _MesOrdonnancesScreenState();
}

class _MesOrdonnancesScreenState extends State<MesOrdonnancesScreen> {
  List<OrdonnanceRx>? _liste;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    CompteApi()
        .mesOrdonnances()
        .then((d) {
          if (mounted) {
            setState(() => _liste = d.map(OrdonnanceRx.fromJson).toList());
          }
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

  @override
  Widget build(BuildContext context) {
    final l = _liste;
    return Scaffold(
      appBar: AppBar(title: const Text('Mes ordonnances')),
      body: l == null
          ? Center(
              child: _erreur == null
                  ? const CircularProgressIndicator()
                  : Text(_erreur!),
            )
          : l.isEmpty
          ? const Center(
              child: Text(
                'Aucune ordonnance.',
                style: TextStyle(color: Kolors.kTextMuted),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final o in l)
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.receipt_long_rounded,
                        color: Kolors.kPrimary,
                      ),
                      title: Text(
                        '${o.etablissement}${o.date == null ? '' : ' · ${o.date}'}',
                      ),
                      subtitle: Text(
                        '${o.lignes.map((x) => x.produit).join(', ')}\n${o.statutLabel}',
                      ),
                      isThreeLine: true,
                      onTap: () => afficherOrdonnance(context, o),
                    ),
                  ),
              ],
            ),
    );
  }
}
