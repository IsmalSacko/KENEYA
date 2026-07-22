import 'package:flutter/material.dart';

/// Palette « Émeraude santé » — identité KENEYA+ (santé, cabinets & pharmacies).
/// Les noms de tokens sont conservés : changer une valeur ici met à jour tous
/// les écrans qui référencent `Kolors.*`.
class Kolors {
  // Brand — vert émeraude (santé, soin, croix verte des pharmacies)
  static const Color kPrimary = Color(0xFF0E9F6E);
  static const Color kPrimaryDark = Color(0xFF0B7D57);
  static const Color kPrimaryLight = Color(0xFF34D399);
  static const Color kBlue = Color(0xFF14B8A6); // teal (accent / dégradés)
  static const Color kSecondaryLight = Color(0xFFD1FAE5); // teinte émeraude

  // Neutrals — légèrement teintés vert pour l'harmonie
  static const Color kGray = Color(0xFF5B6B63);
  static const Color kGrayLight = Color(0xFFC7D3CD);
  static const Color kWhite = Color(0xFFFFFFFF);
  static const Color kOffWhite = Color(0xFFF5FAF7); // fond d'écran blanc verdâtre
  static const Color kDark = Color(0xFF08261C); // vert-charbon profond
  static const Color kSurface = Color(0xFFFFFFFF);
  static const Color kBorder = Color(0xFFE2ECE7);
  static const Color kTextHigh = Color(0xFF0B3D2E);
  static const Color kTextMuted = Color(0xFF4B6358);

  // Status
  static const Color kGold = Color(0xFFF59E0B);
  static const Color kRed = Color(0xFFDC2626);
  static const Color kSuccess = Color(0xFF16A34A);
  static const Color kWarning = Color(0xFFF59E0B);
  static const Color kGreen = Color(0xFF16A34A);
}
