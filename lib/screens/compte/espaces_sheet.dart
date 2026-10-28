import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../compte/compte_controller.dart';
import '../../compte/compte_models.dart';
import '../../controllers/auth_controller.dart';
import 'cadre_acces.dart';
import 'connexion_screen.dart';
import 'creer_etablissement_screen.dart';
import '../../common/widgets/feuille.dart';

/// Bouton de la barre du haut : passer de « Ma santé » à un espace pro, ou
/// d'un établissement à l'autre (comme le sélecteur de boutique de Ngoni).
class BoutonEspaces extends StatelessWidget {
  const BoutonEspaces({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Changer d’espace',
      icon: const Icon(Icons.swap_horiz_rounded),
      onPressed: () => afficherEspaces(context),
    );
  }
}

Future<void> afficherEspaces(BuildContext context) {
  // Les espaces et les accès (console) à jour à chaque ouverture.
  context.read<CompteController>().rafraichir();
  return feuille<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _FeuilleEspaces(),
  );
}

class _FeuilleEspaces extends StatelessWidget {
  const _FeuilleEspaces();

  Future<void> _ouvrir(
    BuildContext context,
    Future<bool> Function() action,
  ) async {
    final compte = context.read<CompteController>();
    final navigator = Navigator.of(context);
    final ok = await action();
    if (!context.mounted) return;
    if (ok) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      afficherMessage(
        context,
        compte.erreur ?? 'Impossible d’ouvrir cet espace.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final compte = context.watch<CompteController>();
    final auth = context.read<AuthController>();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mes espaces',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Kolors.kTextHigh,
              ),
            ),
            const SizedBox(height: 12),
            if (!compte.connecte)
              _Ligne(
                icone: Icons.login_rounded,
                titre: 'Se connecter à Ngoni Santé',
                sousTitre:
                    'Pour retrouver « Ma santé » et tous vos établissements.',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConnexionScreen()),
                ),
              )
            else ...[
              if (compte.sessionExpiree)
                _Ligne(
                  icone: Icons.login_rounded,
                  titre: 'Reconnectez-vous',
                  sousTitre:
                      'Votre session a expiré : reconnectez-vous pour tout mettre à jour.',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ConnexionScreen()),
                  ),
                ),
              _Ligne(
                icone: Icons.favorite_rounded,
                titre: 'Ma santé',
                sousTitre: compte.personne!.nom,
                actif: compte.espaceActif == null,
                onTap: () => _ouvrir(context, () => compte.quitterEspace(auth)),
              ),
              for (final espace in compte.espaces)
                _Ligne(
                  icone: Icons.local_hospital_rounded,
                  titre: espace.etablissementNom,
                  sousTitre: '${espace.roleLabel} · ${espace.profilLabel}',
                  actif: compte.espaceActif == espace.membreUuid,
                  desactive: !espace.actif,
                  onTap: () =>
                      _ouvrir(context, () => compte.ouvrirEspace(espace, auth)),
                ),
              if (compte.personne?.pro == true)
                _Ligne(
                  icone: Icons.add_business_rounded,
                  titre: 'Créer mon établissement',
                  sousTitre: 'Cabinet, pharmacie, centre de santé…',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreerEtablissementScreen(),
                    ),
                  ),
                ),
            ],
            if (compte.chargement)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({
    required this.icone,
    required this.titre,
    required this.sousTitre,
    required this.onTap,
    this.actif = false,
    this.desactive = false,
  });

  final IconData icone;
  final String titre;
  final String sousTitre;
  final VoidCallback onTap;
  final bool actif;
  final bool desactive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Kolors.kSurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: desactive ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: actif ? Kolors.kJaune : Kolors.kBorder,
                width: actif ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: actif ? Kolors.kPrimary : Kolors.kSecondaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icone,
                    color: actif ? Kolors.kJaune : Kolors.kPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Kolors.kTextHigh,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        desactive ? 'Accès désactivé' : sousTitre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Kolors.kTextMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  actif
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: actif ? Kolors.kPrimary : Kolors.kTextMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Utilisé par les écrans qui listent les espaces sans passer par la feuille.
Future<void> ouvrirEspace(BuildContext context, Espace espace) async {
  final compte = context.read<CompteController>();
  final ok = await compte.ouvrirEspace(espace, context.read<AuthController>());
  if (!ok && context.mounted) {
    afficherMessage(
      context,
      compte.erreur ?? 'Impossible d’ouvrir cet espace.',
    );
  }
}
