import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../common/utils/kcolors.dart';
import 'abonnement_screen.dart';

/// Un module ou une fonction que la formule n'ouvre pas : visible, avec un
/// cadenas et la formule qui l'ouvre.
class FonctionVerrouillee extends StatelessWidget {
  const FonctionVerrouillee({
    required this.titre,
    required this.formule,
    required this.admin,
    super.key,
  });

  final String titre;

  /// La formule qui l'ouvre (« Pro »).
  final String formule;

  /// L'administrateur peut changer de formule ; les autres le lui demandent.
  final bool admin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Kolors.kJauneDoux,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_rounded,
                size: 36,
                color: Kolors.kPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              titre,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Kolors.kTextHigh,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              admin
                  ? 'Avec la formule $formule.'
                  : 'Avec la formule $formule : demandez à votre administrateur.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Kolors.kTextMuted),
            ),
            if (admin) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ouvrirAbonnement(context),
                icon: const Icon(Icons.workspace_premium_outlined),
                label: const Text('Voir les formules'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Une ligne de menu fermée par la formule : cadenas et « Avec Pro ».
class LigneVerrouillee extends StatelessWidget {
  const LigneVerrouillee({
    required this.icone,
    required this.titre,
    required this.formule,
    super.key,
  });

  final IconData icone;
  final String titre;
  final String formule;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icone, color: Kolors.kTextMuted),
      title: Text(titre, style: const TextStyle(color: Kolors.kTextMuted)),
      subtitle: Text('Avec la formule $formule'),
      trailing: const Icon(Icons.lock_rounded, color: Kolors.kTextMuted),
      onTap: () => ouvrirAbonnement(context),
    );
  }
}

Future<void> ouvrirAbonnement(BuildContext context) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => const AbonnementScreen()));
