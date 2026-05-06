import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Stitch Design Tokens: Futuristic Islamic Studio
  static const gold = Color(0xFFF2EA4B);
  static const goldDim = Color(0xFFd3cb2c);
  static const blueAccent = Color(0xFF42C4E7);
  static const surface = Color(0xFF121414);
  static const surfaceContainer = Color(0xFF1e2020);
  static const surfaceContainerHigh = Color(0xFF282a2b);
  static const surfaceContainerHighest = Color(0xFF333535);
  static const onSurface = Color(0xFFe2e2e2);
  static const onSurfaceVariant = Color(0xFFcbc7ae);
  static const navyGlass = Color(0xFF15215D);
  static const outline = Color(0xFF94917a);

  static final darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: surface,
    colorScheme: ColorScheme.fromSeed(
      seedColor: gold,
      brightness: Brightness.dark,
      primary: gold,
      secondary: blueAccent,
      surface: surface,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.inter(fontSize: 48, fontWeight: FontWeight.w700, letterSpacing: -0.02, height: 1.1),
      headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w600, letterSpacing: -0.01, height: 1.2),
      headlineMedium: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, height: 1.3),
      bodyLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w400, height: 1.6),
      bodyMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.05, height: 1.0),
      labelSmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.05, height: 1.4),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: navyGlass.withValues(alpha: 0.2),
      foregroundColor: gold,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: gold, letterSpacing: 2),
    ),
    cardTheme: CardThemeData(
      color: surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceContainer,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: gold)),
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: const Color(0xFF1e1c00),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceContainerHighest,
      selectedItemColor: gold,
      unselectedItemColor: onSurfaceVariant,
      elevation: 0,
    ),
  );
}
