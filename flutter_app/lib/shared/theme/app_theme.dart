import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color primaryGold = Color(0xFFB07D18);
  static const Color primaryGoldLight = Color(0xFFF9EDCC);
  static const Color primaryGoldDark = Color(0xFF8F6210);

  static const Color backgroundGray = Color(0xFFF9FAFB);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color borderGray = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);

  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGold,
          primary: primaryGold,
          surface: surfaceWhite,
        ),
        scaffoldBackgroundColor: backgroundGray,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: surfaceWhite,
          foregroundColor: textPrimary,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        // Fix: Flutter 3.x uses CardThemeData, not CardTheme
        cardTheme: CardThemeData(
          color: surfaceWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: borderGray),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryGold,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: backgroundGray,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderGray),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: borderGray),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primaryGold, width: 2),
          ),
        ),
      );
}