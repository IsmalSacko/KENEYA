import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'kcolors.dart';

/// Le thème de la famille Ngoni (comme Ngoni Caisse) : bleu nuit et jaune,
/// titres en Poppins, texte courant en Nunito Sans.
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: Kolors.kPrimary,
      brightness: Brightness.light,
      primary: Kolors.kPrimary,
      onPrimary: Colors.white,
      primaryContainer: Kolors.kSecondaryLight,
      onPrimaryContainer: Kolors.kPrimaryDark,
      secondary: Kolors.kJaune,
      onSecondary: Kolors.kPrimary,
      secondaryContainer: Kolors.kJauneDoux,
      onSecondaryContainer: Kolors.kPrimary,
      error: Kolors.kRed,
      onError: Colors.white,
      surface: Kolors.kSurface,
      onSurface: Kolors.kTextHigh,
      onSurfaceVariant: Kolors.kTextMuted,
      surfaceContainerHighest: Kolors.kOffWhite,
      outline: Kolors.kBorderStrong,
      outlineVariant: Kolors.kBorder,
    );

    // Titres ronds et francs (Poppins), texte courant lisible (Nunito Sans).
    final bodyFont = GoogleFonts.nunitoSansTextTheme();
    final displayFont = GoogleFonts.poppinsTextTheme();
    final textTheme = bodyFont
        .copyWith(
          displayLarge: displayFont.displayLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          displayMedium: displayFont.displayMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          displaySmall: displayFont.displaySmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          headlineLarge: displayFont.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          headlineMedium: displayFont.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: displayFont.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleLarge: displayFont.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          titleMedium: displayFont.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        )
        .apply(bodyColor: Kolors.kTextHigh, displayColor: Kolors.kPrimary);
    final label = bodyFont.labelLarge;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Kolors.kOffWhite,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Kolors.kPrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      // Ombre teintée bleu nuit, pas grise : les cartes semblent éclairées.
      cardTheme: CardThemeData(
        color: Kolors.kSurface,
        elevation: 3,
        shadowColor: Kolors.kPrimary.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Kolors.kBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF8FAFD),
        helperMaxLines: 2,
        errorMaxLines: 3,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: GoogleFonts.nunitoSans(color: Kolors.kGray, fontSize: 14),
        prefixIconColor: WidgetStateColor.resolveWith(
          (s) =>
              s.contains(WidgetState.focused) ? Kolors.kPrimary : Kolors.kGray,
        ),
        floatingLabelStyle: const TextStyle(
          color: Kolors.kPrimary,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Kolors.kBorderStrong, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Kolors.kBorderStrong, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Kolors.kPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Kolors.kRed, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Kolors.kPrimary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Kolors.kBorderStrong,
          // Le bouton principal porte un halo bleu nuit : c'est lui que l'œil
          // cherche.
          elevation: 4,
          shadowColor: Kolors.kPrimary.withValues(alpha: 0.45),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: label?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 15.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Kolors.kPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: Kolors.kBorderStrong, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: label?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Kolors.kPrimary,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: Kolors.kPrimary.withValues(alpha: 0.40),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: label?.copyWith(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Kolors.kPrimary,
          textStyle: label?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Kolors.kPuce,
        selectedColor: Kolors.kJaune,
        checkmarkColor: Kolors.kPrimary,
        labelStyle: label?.copyWith(
          color: Kolors.kPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Kolors.kJaune : null,
          ),
          foregroundColor: const WidgetStatePropertyAll(Kolors.kPrimary),
        ),
      ),
      // Le bouton d'ajout est jaune, comme dans Ngoni Caisse.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Kolors.kJaune,
        foregroundColor: Kolors.kPrimary,
        elevation: 2,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Kolors.kPrimary,
      ),
      // Le jaune marque l'onglet ouvert.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Kolors.kWhite,
        elevation: 3,
        height: 66,
        shadowColor: Kolors.kPrimary.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        indicatorColor: Kolors.kJaune,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.nunitoSans(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
            fontSize: 11.5,
            color: states.contains(WidgetState.selected)
                ? Kolors.kPrimary
                : Kolors.kGray,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? Kolors.kPrimary
                : Kolors.kGray,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Kolors.kWhite,
        selectedIconTheme: const IconThemeData(color: Kolors.kPrimary),
        unselectedIconTheme: const IconThemeData(color: Kolors.kGray),
        selectedLabelTextStyle: GoogleFonts.nunitoSans(
          color: Kolors.kPrimary,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: GoogleFonts.nunitoSans(
          color: Kolors.kGray,
          fontWeight: FontWeight.w600,
        ),
        indicatorColor: Kolors.kJaune,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Kolors.kPrimary,
        contentTextStyle: GoogleFonts.nunitoSans(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Kolors.kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      // Le fond des écrans : les cartes blanches s'y détachent.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Kolors.kOffWhite,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: Kolors.kBorderStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Kolors.kSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: const ListTileThemeData(iconColor: Kolors.kPrimary),
      // Éteint ne doit pas avoir l'air désactivé : rond foncé sur un fond
      // gris bien visible, bordure nette. Seul un interrupteur vraiment
      // inactif est pâle.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return Kolors.kBorderStrong;
          return s.contains(WidgetState.selected)
              ? Colors.white
              : Kolors.kTextMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return Kolors.kBorder;
          return s.contains(WidgetState.selected)
              ? Kolors.kPrimary
              : Kolors.kBorderStrong;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return Kolors.kBorder;
          return s.contains(WidgetState.selected)
              ? Kolors.kPrimary
              : Kolors.kTextMuted;
        }),
      ),
      dividerTheme: const DividerThemeData(color: Kolors.kBorder, thickness: 1),
    );
  }
}
