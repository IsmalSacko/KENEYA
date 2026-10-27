import 'package:flutter/material.dart';

/// Palette de la famille Ngoni (comme Ngoni Caisse) : bleu nuit pour la
/// structure et les actions principales, jaune pour ce qui est choisi et mis
/// en avant, vert pour ce qui va bien.
/// Les noms de tokens sont conservés : changer une valeur ici met à jour tous
/// les écrans qui référencent `Kolors.*`.
class Kolors {
  // Brand — bleu nuit de Ngoni
  static const Color kPrimary = Color(0xFF0F2A5C);
  static const Color kPrimaryDark = Color(0xFF0A1E45);
  static const Color kPrimaryLight = Color(0xFF22498F);
  static const Color kBlue = Color(0xFF1C3B78); // bleu nuit clair (dégradés)
  static const Color kSecondaryLight = Color(0xFFE4EBF7); // teinte bleu nuit

  // Jaune Ngoni : ce qui est choisi, les chiffres mis en avant. Jamais du
  // texte sur fond clair.
  static const Color kJaune = Color(0xFFFFCC1F);
  static const Color kJauneDoux = Color(0xFFFFF4CC);

  // Neutrals — gris-bleu, comme Ngoni Caisse
  static const Color kGray = Color(0xFF5A6478);
  static const Color kGrayLight = Color(0xFFD7DEEA);
  static const Color kWhite = Color(0xFFFFFFFF);
  static const Color kOffWhite = Color(0xFFEEF2F8); // fond des écrans
  static const Color kDark = Color(0xFF111B30);
  static const Color kSurface = Color(0xFFFFFFFF);
  static const Color kBorder = Color(0xFFE3E8F0);
  static const Color kBorderStrong = Color(0xFFD7DEEA);
  static const Color kPuce = Color(0xFFE8EDF5);
  static const Color kTextHigh = Color(0xFF111B30);
  static const Color kTextMuted = Color(0xFF5A6478);

  // Status
  static const Color kGold = Color(0xFFB45309); // ambre lisible sur fond clair
  static const Color kRed = Color(0xFFB42318);
  static const Color kSuccess = Color(0xFF16A34A);
  static const Color kWarning = Color(0xFFD97706);
  static const Color kGreen = Color(0xFF16A34A);

  // Teintes d'appoint pour distinguer les rôles, lisibles sur fond clair.
  static const Color kTeal = Color(0xFF0E7490);
  static const Color kViolet = Color(0xFF6D28D9);

  /// Dégradé des cartes de tête : du clair en haut à gauche au profond en bas
  /// à droite.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22498F), Color(0xFF0E1F4A)],
  );

  /// Ombre bleutée des cartes posées sur le fond : elles semblent éclairées.
  static List<BoxShadow> softShadow({double strength = 1}) => [
    BoxShadow(
      color: kPrimary.withValues(alpha: 0.06 * strength),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: kPrimary.withValues(alpha: 0.10 * strength),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}
