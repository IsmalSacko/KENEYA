import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../abonnement/achats_apple_controller.dart';
import '../../abonnement/boutique_apple.dart';
import '../../common/utils/kcolors.dart';
import 'abonnement_screen.dart';

/// Les conditions d'utilisation standard d'Apple, à citer près d'un abonnement.
const conditionsApple =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';
const confidentialiteNgoniSante = 'https://keneya.ismaeldev.fr/confidentialite';
const gererAbonnementsApple = 'https://apps.apple.com/account/subscriptions';

/// iPhone et iPad : les formules s'achètent par l'achat intégré d'Apple, au
/// mois ou à l'année, au prix d'Apple dans le pays de l'acheteur. Aucun autre
/// moyen de paiement n'est cité ici (règle 3.1.1 de l'App Store).
class OffresApple extends StatefulWidget {
  const OffresApple({
    required this.formules,
    required this.compte,
    required this.actuelle,
    required this.onAbonne,
    this.sansEcheance = false,
    super.key,
  });

  /// Les formules du serveur, avec le produit Apple de chaque tarif.
  final List<Map<String, dynamic>> formules;

  /// L'uuid de l'établissement, confié à Apple avec l'achat.
  final String? compte;

  /// La formule en cours, s'il y en a une.
  final String? actuelle;

  /// Un achat validé : l'écran relit l'état.
  final Future<void> Function() onAbonne;

  /// L'abonnement en cours est sans échéance (accordé par Ngoni Santé) : le
  /// serveur refuserait tout achat, qu'Apple aurait pourtant encaissé.
  final bool sansEcheance;

  @override
  State<OffresApple> createState() => _OffresAppleState();
}

class _OffresAppleState extends State<OffresApple> {
  int _mois = 1;
  late final AchatsAppleController _achats;
  late Future<Map<String, ProduitApple>> _produits;
  int _messageVu = 0;

  @override
  void initState() {
    super.initState();
    _achats = context.read<AchatsAppleController>();
    _messageVu = _achats.numeroMessage;
    _achats.addListener(_surAchat);
    _produits = _achats.produits(_ids());
    // Un achat arrivé avant l'ouverture de l'établissement : validé maintenant.
    _achats.reprendre();
  }

  @override
  void didUpdateWidget(OffresApple avant) {
    super.didUpdateWidget(avant);
    if (!_memesIds(avant)) _produits = _achats.produits(_ids());
  }

  @override
  void dispose() {
    _achats.removeListener(_surAchat);
    super.dispose();
  }

  Set<String> _ids() => {
    for (final f in widget.formules)
      for (final t in (f['tarifs'] as List?) ?? const [])
        if (t is Map && t['apple_produit'] is String)
          t['apple_produit'] as String,
  };

  bool _memesIds(OffresApple avant) {
    final ids = _ids();
    final anciens = {
      for (final f in avant.formules)
        for (final t in (f['tarifs'] as List?) ?? const [])
          if (t is Map && t['apple_produit'] is String)
            t['apple_produit'] as String,
    };
    return ids.length == anciens.length && ids.containsAll(anciens);
  }

  void _surAchat() {
    if (!mounted) return;
    setState(() {});
    final message = _achats.message;
    if (message == null || _achats.numeroMessage == _messageVu) return;
    _messageVu = _achats.numeroMessage;
    // Le dernier message d'abord : pas d'attente derrière le précédent.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _achats.reussi ? Kolors.kSuccess : null,
        ),
      );
    if (_achats.reussi) widget.onAbonne();
  }

  /// Le produit Apple de cette formule pour la durée choisie.
  String? _produit(Map<String, dynamic> f) {
    final tarif = (f['tarifs'] as List? ?? const [])
        .whereType<Map>()
        .where((t) => t['mois'] == _mois)
        .firstOrNull;
    final id = tarif?['apple_produit'];
    return id is String ? id : null;
  }

  void _ouvrir(String lien) =>
      launchUrl(Uri.parse(lien), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    // Rien à vendre : ni achat, ni « Restaurer », le client paierait pour rien.
    if (widget.sansEcheance) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: Text(
          'Votre abonnement est sans échéance : vous n’avez rien à payer.',
          key: Key('abonnement-sans-echeance'),
          style: TextStyle(color: Kolors.kTextMuted),
        ),
      );
    }
    final compte = widget.compte;
    return FutureBuilder<Map<String, ProduitApple>>(
      future: _produits,
      builder: (context, instantane) {
        final disponibles = instantane.data ?? const <String, ProduitApple>{};
        final formules = [
          for (final f in widget.formules)
            if ((f['tarifs'] as List? ?? const []).whereType<Map>().any(
              (t) => disponibles.containsKey(t['apple_produit']),
            ))
              f,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text(
              'Choisir une formule',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (instantane.connectionState != ConnectionState.done)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (formules.isEmpty || compte == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Les abonnements ne sont pas disponibles pour le moment.',
                  style: TextStyle(color: Kolors.kTextMuted),
                ),
              )
            else ...[
              SegmentedButton<int>(
                key: const Key('duree-apple'),
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 1, label: Text('Mensuel')),
                  ButtonSegment(value: 12, label: Text('Annuel')),
                ],
                selected: {_mois},
                onSelectionChanged: (s) => setState(() => _mois = s.first),
              ),
              const SizedBox(height: 12),
              for (final f in formules)
                CarteFormule(
                  formule: f,
                  prix: switch (disponibles[_produit(f)]) {
                    final p? => '${p.prix} / ${_mois == 12 ? 'an' : 'mois'}',
                    null => null,
                  },
                  actuelle: f['code'] == widget.actuelle,
                  bouton: disponibles[_produit(f)] == null
                      ? 'Pas proposé sur cette durée'
                      : 'S’abonner',
                  cleBouton: Key('acheter-apple-${f['code']}'),
                  onChoisir: disponibles[_produit(f)] == null || _achats.enCours
                      ? null
                      : () => _achats.acheter(_produit(f)!, compte: compte),
                ),
            ],
            if (compte != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('restaurer-apple'),
                  onPressed: _achats.enCours
                      ? null
                      : () => _achats.restaurer(compte: compte),
                  child: const Text('Restaurer mes achats'),
                ),
              ),
            const Text(
              'Abonnement à renouvellement automatique. Le paiement est débité sur votre compte Apple à la confirmation de l’achat. '
              'L’abonnement se renouvelle pour la même durée, sauf s’il est annulé au moins 24 heures avant la fin de la période en cours. '
              'Gérez-le ou annulez-le dans les réglages de votre compte Apple.',
              style: TextStyle(color: Kolors.kTextMuted, fontSize: 12.5),
            ),
            Wrap(
              spacing: 4,
              children: [
                TextButton(
                  onPressed: () => _ouvrir(conditionsApple),
                  child: const Text('Conditions d’utilisation'),
                ),
                TextButton(
                  onPressed: () => _ouvrir(confidentialiteNgoniSante),
                  child: const Text('Confidentialité'),
                ),
                TextButton(
                  onPressed: () => _ouvrir(gererAbonnementsApple),
                  child: const Text('Gérer mon abonnement'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
