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
      secondary: Kolors.kBlue,
      onSecondary: Colors.white,
      error: Kolors.kRed,
      onError: Colors.white,
      surface: Kolors.kSurface,
      onSurface: Kolors.kTextHigh,
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
      appBarTheme: const AppBarTheme(
        backgroundColor: Kolors.kPrimary,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Kolors.kSurface,
        elevation: 0.6,
        shadowColor: const Color(0x14000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Kolors.kBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Kolors.kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Kolors.kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Kolors.kPrimary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Kolors.kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Kolors.kPrimary,
          side: const BorderSide(color: Kolors.kPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: Kolors.kPrimary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        selectedIconTheme: const IconThemeData(color: Kolors.kPrimary),
        selectedLabelTextStyle: const TextStyle(
          color: Kolors.kPrimary,
          fontWeight: FontWeight.w700,
        ),
        indicatorColor: Kolors.kPrimary.withValues(alpha: 0.10),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Kolors.kDark,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: Kolors.kBorder, thickness: 1),
    );
  }
}
