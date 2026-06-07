import 'package:flutter/material.dart';

class AppTheme {
  // ── Palette verte RSS BANK ────────────────────────────────────────────────
  static const Color primaryGreen   = Color(0xFF1B7F4E);   // Vert principal
  static const Color darkGreen      = Color(0xFF0D5235);   // Vert foncé
  static const Color lightGreen     = Color(0xFFDFF2EB);   // Vert clair (fond chips)
  static const Color cardGreenStart = Color(0xFF239A61);   // Dégradé carte début
  static const Color cardGreenEnd   = Color(0xFF0D5235);   // Dégradé carte fin

  // ── Compatibilité (anciens noms gardés pour les widgets existants) ─────────
  static const Color primaryColor   = primaryGreen;
  // Gardé pour éviter de casser les références existantes
  static const Color primaryGold    = primaryGreen;
  static const Color darkGold       = darkGreen;
  static const Color lightGold      = lightGreen;
  static const Color cardGoldStart  = cardGreenStart;
  static const Color cardGoldEnd    = cardGreenEnd;

  static const Color secondaryColor = Color(0xFF2E7D32);
  static const Color accentColor    = Color(0xFFFF7675);

  // ── Fond & texte ──────────────────────────────────────────────────────────
  static const Color backgroundColor = Color(0xFFF4F6F9);
  static const Color surfaceColor     = Colors.white;
  static const Color textPrimary      = Color(0xFF1A1A2E);
  static const Color textSecondary    = Color(0xFF6B7280);
  static const Color textHint         = Color(0xFFB2BEC3);
  static const Color dividerColor     = Color(0xFFE5E7EB);
  static const Color errorColor       = Color(0xFFD63031);
  static const Color successColor     = Color(0xFF00B894);

  // ── Theme principal ────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: darkGreen,
        surface: surfaceColor,
        error: errorColor,
      ),
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
        bodySmall: TextStyle(fontSize: 12, color: textHint),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        hintStyle: const TextStyle(color: textHint),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightGreen,
        selectedColor: primaryGreen,
        labelStyle: const TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      dividerTheme: const DividerThemeData(color: dividerColor, thickness: 1),
    );
  }
}
