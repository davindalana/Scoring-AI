import 'package:flutter/material.dart';

class ArcheryColors {
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldDark = Color(0xFFD97706);
  static const Color red = Color(0xFFEF4444);
  static const Color redDark = Color(0xFFDC2626);
  static const Color blue = Color(0xFF0284C7);
  static const Color blueDark = Color(0xFF0369A1);
  static const Color black = Color(0xFF334155);
  static const Color blackDark = Color(0xFF1E293B);
  static const Color white = Color(0xFFF1F5F9);
  static const Color whiteDark = Color(0xFFE2E8F0);
  static const Color miss = Color(0xFF475569);

  static const Color bgPrimary = Color(0xFF0D1117);
  static const Color bgSecondary = Color(0xFF161B22);
  static const Color bgCard = Color(0xFF1E2633);
  static const Color borderColor = Color(0x26FFFFFF);
  static const Color borderActive = Color(0x59FFFFFF);

  static const Color textPrimary = Color(0xFFF0F6FC);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF6E7681);

  static const Color accentGreen = Color(0xFF10B981);
  static const Color accentPurple = Color(0xFF8B5CF6);

  static Color getColorForScore(String? score, {bool isX = false}) {
    if (score == null) return Colors.transparent;
    final s = score.trim().toUpperCase();
    if (isX || s == 'X' || s == '10X') return gold;
    if (s == '10' || s == '9') return gold;
    if (s == '8' || s == '7') return red;
    if (s == '6' || s == '5') return blue;
    if (s == '4' || s == '3') return black;
    if (s == '2' || s == '1') return white;
    return miss;
  }

  static Color getTextColorForScore(String? score, {bool isX = false}) {
    if (score == null) return textMuted;
    final s = score.trim().toUpperCase();
    if (isX || s == 'X' || s == '10X' || s == '10' || s == '9') {
      return Colors.black;
    }
    if (s == '2' || s == '1') {
      return Colors.black87;
    }
    return Colors.white;
  }
}

class ArcheryTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ArcheryColors.bgPrimary,
      colorScheme: const ColorScheme.dark(
        primary: ArcheryColors.gold,
        onPrimary: Colors.black,
        secondary: ArcheryColors.blue,
        surface: ArcheryColors.bgSecondary,
        onSurface: ArcheryColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ArcheryColors.bgSecondary,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: ArcheryColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: ArcheryColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: ArcheryColors.borderColor),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ArcheryColors.gold,
          foregroundColor: Colors.black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ArcheryColors.textPrimary,
          side: const BorderSide(color: ArcheryColors.borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
