import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'kcolors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    final scheme = ColorScheme(
      brightness: Brightness.light,
      primary: Kolors.kPrimary,
      onPrimary: Colors.white,
      primaryContainer: Kolors.kSecondaryLight,
      onPrimaryContainer: Kolors.kPrimaryDark,
      secondary: Kolors.kBlue,
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFCCFBF1),
      onSecondaryContainer: const Color(0xFF0F766E),
      error: Kolors.kRed,
      onError: Colors.white,
      surface: Kolors.kSurface,
      onSurface: Kolors.kTextHigh,
      onSurfaceVariant: Kolors.kTextMuted,
      surfaceContainerHighest: Kolors.kOffWhite,
      outline: Kolors.kBorder,
      outlineVariant: Kolors.kBorder,
    );

    final baseText = GoogleFonts.poppinsTextTheme().apply(
      bodyColor: Kolors.kTextHigh,
      displayColor: Kolors.kTextHigh,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Kolors.kOffWhite,
      textTheme: baseText,
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
      cardTheme: CardThemeData(
        color: Kolors.kSurface,
        elevation: 0,
        shadowColor: const Color(0x140E9F6E),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Kolors.kBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F8F5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: GoogleFonts.poppins(color: Kolors.kGray, fontSize: 14),
        prefixIconColor: Kolors.kGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Kolors.kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Kolors.kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Kolors.kPrimary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Kolors.kRed),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Kolors.kPrimary,
          foregroundColor: Colors.white,
          elevation: 1,
          shadowColor: Kolors.kPrimary.withValues(alpha: 0.35),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Kolors.kPrimary,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: Kolors.kPrimary, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Kolors.kPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: Kolors.kPrimary,
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Kolors.kSecondaryLight,
        labelStyle: GoogleFonts.poppins(
          color: Kolors.kPrimaryDark,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Kolors.kPrimary,
        foregroundColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: Kolors.kPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Kolors.kWhite,
        elevation: 3,
        height: 66,
        indicatorColor: Kolors.kSecondaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: states.contains(WidgetState.selected)
                ? Kolors.kPrimaryDark
                : Kolors.kGray,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? Kolors.kPrimaryDark
                : Kolors.kGray,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Kolors.kWhite,
        selectedIconTheme: const IconThemeData(color: Kolors.kPrimaryDark),
        selectedLabelTextStyle: GoogleFonts.poppins(
          color: Kolors.kPrimaryDark,
          fontWeight: FontWeight.w700,
        ),
        indicatorColor: Kolors.kSecondaryLight,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Kolors.kDark,
        contentTextStyle: GoogleFonts.poppins(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: Kolors.kBorder, thickness: 1),
    );
  }
}
