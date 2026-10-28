import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/feuille.dart';
import '../../compte/compte_controller.dart';
import '../../controllers/user_controller.dart';
import '../../controllers/auth_controller.dart';
import '../abonnement/abonnement_screen.dart';
import '../abonnement/verrou.dart';
import '../compte/espaces_sheet.dart';
import '../rapports/rapport_mensuel_screen.dart';
import 'tabs/profile_tab_state.dart';
import 'tabs/reglages_tab.dart';
import 'tabs/users_tab.dart';

/// Ce que le membre peut ouvrir depuis le menu de l'établissement.
class AccesGestion {
  const AccesGestion({
    this.equipe = false,
    this.reglages = false,
    this.rapport = false,
    this.abonnement = false,
    this.rapportVerrou,
  });

  final bool equipe;
  final bool reglages;
  final bool rapport;

  /// Le rapport n'est pas dans la formule : celle qui l'ouvre (« Pro »).
  final String? rapportVerrou;

  /// Les administrateurs gèrent l'abonnement, même échu.
  final bool abonnement;
}

/// En haut de l'espace : l'abonnement échu (le soin continue, la gestion est
/// fermée) ou l'essai qui se termine, avec le bouton pour s'abonner.
class BandeauAbonnement extends StatelessWidget {
  const BandeauAbonnement({required this.admin, super.key});

  final bool admin;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final jours = auth.joursRestants ?? 0;
    final echu = auth.abonnementEchu;
    final bientot =
        !echu && auth.enEssai && auth.joursRestants != null && jours <= 3;
    if (!echu && !bientot) return const SizedBox.shrink();

    final texte = echu
        ? 'Abonnement échu : le soin continue, la gestion est fermée (équipe, réglages, stock).'
        : 'Essai gratuit : ${jours == 0 ? 'dernier jour' : '$jours jour${jours > 1 ? 's' : ''} restant${jours > 1 ? 's' : ''}'}.';
    return Material(
      color: echu ? Kolors.kRed : Kolors.kJauneDoux,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                admin ? texte : '$texte Prévenez l’administrateur.',
                style: TextStyle(
                  color: echu ? Kolors.kWhite : Kolors.kTextHigh,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (admin)
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: echu ? Kolors.kJaune : Kolors.kPrimary,
                ),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AbonnementScreen()),
                ),
                child: Text(echu ? 'Renouveler' : 'S’abonner'),
              ),
          ],
        ),
      ),
    );
  }
}

/// En haut de l'écran : le nom de l'établissement où l'on travaille. On le
/// touche pour gérer l'établissement, voir son profil ou changer d'espace.
class BoutonEtablissement extends StatelessWidget {
  const BoutonEtablissement({required this.acces, super.key});

  final AccesGestion acces;

  @override
  Widget build(BuildContext context) {
    final espace = context.watch<CompteController>().espaceOuvert;
    final nom = espace?.etablissementNom ?? 'Mon établissement';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _ouvrir(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_hospital_rounded,
                  size: 18,
                  color: Kolors.kJaune,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _ouvrir(BuildContext context) => feuille<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _MenuEtablissement(acces: acces),
  );
}

String _resumeAbonnement(AuthController auth) {
  final a = auth.abonnement;
  if (a == null) return 'Formules et paiement';
  final nom = '${a['formule_nom'] ?? 'Formule'}';
  if (auth.abonnementEchu) return '$nom · échu';
  final jours = auth.joursRestants;
  return jours == null
      ? nom
      : '$nom · $jours jour${jours > 1 ? 's' : ''} restant${jours > 1 ? 's' : ''}';
}

class _MenuEtablissement extends StatelessWidget {
  const _MenuEtablissement({required this.acces});

  final AccesGestion acces;

  void _page(BuildContext context, String titre, Widget page) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(titre)),
          body: page,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final espace = context.watch<CompteController>().espaceOuvert;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              espace?.etablissementNom ?? 'Mon établissement',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Kolors.kTextHigh,
              ),
            ),
            if (espace != null)
              Text(
                'Vous êtes : ${espace.roleLabel} · ${espace.profilLabel}',
                style: const TextStyle(color: Kolors.kTextMuted),
              ),
            const SizedBox(height: 12),
            if (acces.equipe)
              ListTile(
                leading: const Icon(Icons.groups_rounded),
                title: const Text('Équipe'),
                subtitle: const Text(
                  'Ajouter, changer de rôle ou retirer un membre',
                ),
                onTap: () => _page(
                  context,
                  'Équipe',
                  UsersTab(userCtrl: context.read<UserController>()),
                ),
              ),
            if (acces.reglages)
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('Réglages'),
                subtitle: const Text(
                  'Établissement, modules, vente, droits de chacun',
                ),
                onTap: () => _page(context, 'Réglages', const ReglagesTab()),
              ),
            if (acces.abonnement)
              ListTile(
                leading: const Icon(Icons.workspace_premium_outlined),
                title: const Text('Abonnement'),
                subtitle: Text(
                  _resumeAbonnement(context.watch<AuthController>()),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AbonnementScreen()),
                  );
                },
              ),
            if (!acces.rapport && acces.rapportVerrou != null)
              LigneVerrouillee(
                icone: Icons.summarize_outlined,
                titre: 'Rapport du mois',
                formule: acces.rapportVerrou!,
              ),
            if (acces.rapport)
              ListTile(
                leading: const Icon(Icons.summarize_outlined),
                title: const Text('Rapport du mois'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const RapportMensuelScreen(),
                    ),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Mon profil'),
              subtitle: const Text('Mes infos, me déconnecter'),
              onTap: () => _page(context, 'Mon profil', const ProfileTab()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Changer d’espace'),
              subtitle: const Text('Ou revenir à « Ma santé »'),
              onTap: () {
                Navigator.pop(context);
                afficherEspaces(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
