import 'package:flutter/material.dart';

class OrbitColors {
  // Brand Header
  static const Color primaryNavy = Color(0xFF06244D);
  static const Color primaryNavyDark = Color(0xFF031630);
  static const Color brandOrange = Color(0xFFD97706);
  static const Color brandOrangeLight = Color(0xFFF59E0B);

  // Background & Surfaces
  static const Color scaffoldBackground = Color(0xFFF3F6FA);
  static const Color cardSurface = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);

  // Status & Pills
  static const Color pillDark = Color(0xFF082247);
  static const Color creamCard = Color(0xFFFFFBEB);
  static const Color creamBorder = Color(0xFFFEF3C7);
  static const Color bubbleBlue = Color(0xFFE0F2FE);
  static const Color bubbleBlueBorder = Color(0xFFBAE6FD);

  // Texts
  static const Color textNavy = Color(0xFF06244D);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // KPI & Metrics
  static const Color kpiGreen = Color(0xFF10B981);
  static const Color kpiGreenBg = Color(0xFFD1FAE5);
  static const Color kpiOrange = Color(0xFFF59E0B);
  static const Color kpiOrangeBg = Color(0xFFFEF3C7);
  static const Color kpiRed = Color(0xFFEF4444);
  static const Color kpiRedBg = Color(0xFFFEE2E2);

  // Accent & Decorative
  static const Color sunAmber = Color(0xFFFBBF24);
  static const Color coralIcon = Color(0xFFEF4444);
  static const Color coralIconBg = Color(0xFFFEE2E2);

  // Navigation
  static const Color navActive = Color(0xFF06244D);
  static const Color navInactive = Color(0xFF64748B);
}

class OrbitTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: OrbitColors.scaffoldBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: OrbitColors.primaryNavy,
        primary: OrbitColors.primaryNavy,
        surface: OrbitColors.cardSurface,
        background: OrbitColors.scaffoldBackground,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: OrbitColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: OrbitColors.cardBorder, width: 1),
        ),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: OrbitColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}
