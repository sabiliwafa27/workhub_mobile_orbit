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
  static const Color accentCoral = Color(0xFFEF4444);
  static const Color coralIcon = Color(0xFFEF4444);
  static const Color coralIconBg = Color(0xFFFEE2E2);

  // Navigation
  static const Color navActive = Color(0xFF06244D);
  static const Color navInactive = Color(0xFF64748B);
}

class OrbitTheme {
  static ThemeData get lightTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: OrbitColors.primaryNavy,
      primary: OrbitColors.primaryNavy,
      secondary: OrbitColors.brandOrange,
      surface: OrbitColors.cardSurface,
      brightness: Brightness.light,
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: OrbitColors.scaffoldBackground,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: OrbitColors.textNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: OrbitColors.textNavy,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: OrbitColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: OrbitColors.cardBorder, width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: OrbitColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: const TextStyle(color: OrbitColors.textMuted),
        labelStyle: const TextStyle(color: OrbitColors.textSecondary),
        floatingLabelStyle: const TextStyle(color: OrbitColors.primaryNavy),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OrbitColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OrbitColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: OrbitColors.primaryNavy, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: controlShape,
          side: const BorderSide(color: OrbitColors.cardBorder),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: controlShape,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: OrbitColors.primaryNavy,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: OrbitColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFFE7EDF6),
        elevation: 0,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: OrbitColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: OrbitColors.cardSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: OrbitColors.primaryNavyDark,
        contentTextStyle: TextStyle(color: scheme.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: OrbitColors.primaryNavy,
        linearTrackColor: OrbitColors.cardBorder,
        circularTrackColor: OrbitColors.cardBorder,
      ),
      dividerTheme: const DividerThemeData(
        color: OrbitColors.divider,
        space: 1,
        thickness: 1,
      ),
    );
  }
}
