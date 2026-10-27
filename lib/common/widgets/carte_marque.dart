import 'package:flutter/material.dart';

import '../utils/kcolors.dart';

/// Carte de tête de la famille Ngoni : dégradé bleu nuit, halo bleuté, texte
/// blanc par défaut. Les accents (chiffre clé, anneau d'avatar) sont en jaune.
class CarteMarque extends StatelessWidget {
  const CarteMarque({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: Kolors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Kolors.kPrimary.withValues(alpha: 0.30),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Kolors.kWhite),
        child: child,
      ),
    );
  }
}

/// Une icône dans un anneau jaune, posée sur [CarteMarque].
class AvatarMarque extends StatelessWidget {
  const AvatarMarque(this.icon, {this.size = 56, super.key});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Kolors.kJaune,
        boxShadow: [
          BoxShadow(
            color: Kolors.kJaune.withValues(alpha: 0.45),
            blurRadius: 16,
          ),
        ],
      ),
      child: Container(
        width: size - 6,
        height: size - 6,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Kolors.kPrimaryDark,
        ),
        child: Icon(icon, color: Kolors.kJaune, size: size * 0.48),
      ),
    );
  }
}
