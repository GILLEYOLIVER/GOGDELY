import 'package:flutter/material.dart';

/// GOG-088: approved electric-blue and graphite visual direction.
abstract final class GogdelyColors {
  static const blue = Color(0xFF2563EB);
  static const blueHover = Color(0xFF1D4ED8);
  static const accent = Color(0xFF60A5FA);
  static const graphite = Color(0xFF151B2B);
  static const lightBackground = Color(0xFFF2F5FF);
  static const darkBackground = Color(0xFF101522);
  static const darkSurface = Color(0xFF253047);
  static const lightText = Color(0xFF1E293B);
  static const darkText = Color(0xFFF8FAFC);
  static const mutedLight = Color(0xFF64748B);
  static const mutedDark = Color(0xFFB8C4DC);
}

ThemeData gogdelyTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: GogdelyColors.blue,
    brightness: brightness,
    primary: dark ? GogdelyColors.accent : GogdelyColors.blue,
    onPrimary: dark ? GogdelyColors.graphite : Colors.white,
    surface: dark ? GogdelyColors.darkSurface : Colors.white,
    onSurface: dark ? GogdelyColors.darkText : GogdelyColors.lightText,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor:
        dark ? GogdelyColors.darkBackground : GogdelyColors.lightBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? GogdelyColors.darkBackground : Colors.white,
      foregroundColor: dark ? GogdelyColors.darkText : GogdelyColors.lightText,
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: dark ? GogdelyColors.darkSurface : Colors.white,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? GogdelyColors.darkSurface : const Color(0xFFEDF2FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );
}
