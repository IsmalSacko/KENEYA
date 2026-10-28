import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../common/utils/kcolors.dart';
import '../../common/widgets/feuille.dart';
import '../../compte/compte_controller.dart';
import '../../controllers/user_controller.dart';
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
  });

  final bool equipe;
  final bool reglages;
  final bool rapport;
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
                subtitle: const Text('Ajouter ou retirer un membre'),
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
                subtitle: const Text('Services, tarifs, droits de chacun'),
                onTap: () => _page(context, 'Réglages', const ReglagesTab()),
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
              subtitle: const Text('Mon nom, mon PIN, me déconnecter'),
              onTap: () => _page(context, 'Mon profil', const ProfileTab()),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.swap_horiz_rounded),
              title: const Text('Changer d’établissement'),
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
