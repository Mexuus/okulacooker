import 'package:flutter/material.dart';

import '../models/settings.dart';

/// Builds Material 3 themes for TapCook. Uses the bundled Schibsted Grotesk
/// typeface. The Fall theme is the seasonal look; all themes are free.
class AppThemes {
  static const _fontFamily = 'SchibstedGrotesk';

  static ThemeData of(AppTheme theme) {
    switch (theme) {
      case AppTheme.fresh:
        return _build(const Color(0xFF2E7D4F), Brightness.light,
            scaffold: const Color(0xFFF6FAF6));
      case AppTheme.fall:
        return _build(const Color(0xFFBF5B04), Brightness.light,
            scaffold: const Color(0xFFFBF3E9));
      case AppTheme.midnight:
        return _build(const Color(0xFF7FB3FF), Brightness.dark,
            scaffold: const Color(0xFF12151C));
    }
  }

  static ThemeData _build(Color seed, Brightness brightness,
      {required Color scaffold}) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _fontFamily,
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: _fontFamily,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: _fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
