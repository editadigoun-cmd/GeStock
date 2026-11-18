import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class GeStockColors {
  static const emerald = Color(0xFF00CFA3);
  static const deepEmerald = Color(0xFF063C35);
  static const mint = Color(0xFF55F2C1);
  static const ink = Color(0xFF101C1A);
  static const canvas = Color(0xFFF4F8F6);
  static const surface = Color(0xFFFFFFFF);
  static const muted = Color(0xFF71817C);
  static const line = Color(0xFFE7EFEB);
  static const amber = Color(0xFFF2B65D);
  static const red = Color(0xFFE56F72);
}

abstract final class GeStockTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: GeStockColors.emerald,
      brightness: Brightness.light,
      surface: GeStockColors.surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: GeStockColors.canvas,
      textTheme: GoogleFonts.manropeTextTheme().apply(
        bodyColor: GeStockColors.ink,
        displayColor: GeStockColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: GeStockColors.canvas,
        foregroundColor: GeStockColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: GeStockColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: GeStockColors.line),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: GeStockColors.surface,
        indicatorColor: GeStockColors.emerald.withValues(alpha: .13),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? GeStockColors.deepEmerald : GeStockColors.muted,
          );
        }),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: GeStockColors.emerald,
      brightness: Brightness.dark,
      surface: const Color(0xFF14221F),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0D1715),
      textTheme: GoogleFonts.manropeTextTheme(ThemeData.dark().textTheme),
      cardTheme: CardThemeData(
        color: const Color(0xFF14221F),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF263B35)),
        ),
      ),
    );
  }
}
