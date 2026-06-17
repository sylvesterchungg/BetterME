import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Design System Colors from Stitch
  static const Color primary = Color(0xFF4648D4);
  static const Color primaryContainer = Color(0xFF6063EE);
  static const Color secondary = Color(0xFFA43073);
  static const Color secondaryContainer = Color(0xFFFC79BD);
  static const Color tertiary = Color(0xFF904900);
  static const Color tertiaryContainer = Color(0xFFB55D00);
  static const Color surface = Color(0xFFF8F9FF);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFEFF4FF);
  static const Color surfaceContainer = Color(0xFFE5EEFF);
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF);
  static const Color surfaceContainerHighest = Color(0xFFD3E4FE);
  static const Color onSurface = Color(0xFF0B1C30);
  static const Color onSurfaceVariant = Color(0xFF464554);
  static const Color outline = Color(0xFF767586);
  static const Color outlineVariant = Color(0xFFC7C4D7);
  static const Color borderDefault = Color(0xFFE2E8F0);
  static const Color error = Color(0xFFBA1A1A);
  static const Color primaryFixed = Color(0xFFE1E0FF);
  static const Color secondaryFixed = Color(0xFFFFD8E7);
  static const Color tertiaryFixed = Color(0xFFFFDCC5);
  static const Color onTertiaryFixed = Color(0xFF311300);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      secondary: secondary,
      tertiary: tertiary,
      surface: surface,
      error: error,
    ),
    scaffoldBackgroundColor: surface,
    textTheme: GoogleFonts.plusJakartaSansTextTheme(),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: onSurface,
      elevation: 0,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8), // 0.5rem from design system
        side: const BorderSide(color: borderDefault, width: 1),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 20), // 20px horizontal margin
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)), // Pill shape
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: 0, // Soft minimalist, minimal elevation
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none, // Ghost style
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      filled: true,
      fillColor: surfaceContainerLow, // Light gray "ghost" style background
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primary,
      unselectedItemColor: outline,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryFixed;
        return null;
      }),
    ),
  );
}
