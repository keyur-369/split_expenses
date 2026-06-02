import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1A73E8);
  static const Color accentColor = Color(0xFF0D47A1);
  static const Color bgColor = Color(0xFFF8FAFF);
  static const Color cardColor = Colors.white;
  static const Color subtleGray = Color(0xFFF1F4FB);
  static const Color textDark = Color(0xFF1C2B4A);
  static const Color textMid = Color(0xFF5A6A85);
  static const Color errorColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF00897B);
  static const Color borderDefault = Color(0xFFDDE3F0);

  // ── Section palette ──
  static const Color receiveGreen = Color(0xFF00897B);
  static const Color receiveGreenBg = Color(0xFFE6F4F1);
  static const Color oweRed = Color(0xFFE53935);
  static const Color oweRedBg = Color(0xFFFFEBEB);
  static const Color settledBg = Color(0xFFF1F4FB);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: textMid,
        primaryContainer: subtleGray,
        onPrimaryContainer: textDark,
        surface: bgColor,
        error: errorColor,
      ),
      scaffoldBackgroundColor: bgColor,
      textTheme: GoogleFonts.outfitTextTheme(ThemeData.light().textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false, // Left aligned for modern feel
        titleTextStyle: GoogleFonts.outfit(
          color: textDark,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: const IconThemeData(color: textDark),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        color: cardColor,
        margin: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 0,
        ), // Full width or controlled margin
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ), // Pill shape enforced
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: subtleGray,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(20),
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),
    );
  }
}
