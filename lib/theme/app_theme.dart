import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Builds the Material 3 light/dark themes from a single indigo seed with a teal
/// accent, wires the locally-bundled Inter / Inter Tight variable fonts (tabular
/// figures on by default), and attaches the semantic [StatusColors] extension.
class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final base = ColorScheme.fromSeed(seedColor: kIndigoSeed, brightness: brightness);
    // Teal supplies the accent (secondary + tertiary) roles. Taking them from a
    // teal fromSeed keeps M3's AA-aware on-color pairings intact.
    final teal = ColorScheme.fromSeed(seedColor: kTealSeed, brightness: brightness);
    final scheme = base.copyWith(
      secondary: teal.primary,
      onSecondary: teal.onPrimary,
      secondaryContainer: teal.primaryContainer,
      onSecondaryContainer: teal.onPrimaryContainer,
      tertiary: teal.primary,
      onTertiary: teal.onPrimary,
      tertiaryContainer: teal.primaryContainer,
      onTertiaryContainer: teal.onPrimaryContainer,
    );
    final status =
        brightness == Brightness.light ? StatusColors.light : StatusColors.dark;
    final text = _textTheme(scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: text,
      extensions: <ThemeExtension<dynamic>>[status],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 3,
        centerTitle: false,
        titleTextStyle: _tight(scheme.onSurface, 22, 600),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        elevation: 0,
        height: 68,
        labelTextStyle:
            WidgetStatePropertyAll(_inter(scheme.onSurface, 12, 500)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: _inter(Colors.white, 15, 600, tabular: false),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          textStyle: _inter(scheme.primary, 15, 600, tabular: false),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dividerTheme:
          DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            _inter(scheme.onInverseSurface, 14, 500, tabular: false),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
  static TextTheme _textTheme(Color c) {
    return TextTheme(
      displayLarge: _tight(c, 40, 700, height: 1.1),
      displayMedium: _tight(c, 32, 700, height: 1.15),
      displaySmall: _tight(c, 28, 600, height: 1.2),
      headlineLarge: _tight(c, 26, 600, height: 1.2),
      headlineMedium: _tight(c, 22, 600, height: 1.25),
      headlineSmall: _tight(c, 20, 600, height: 1.3),
      titleLarge: _inter(c, 18, 600, height: 1.3),
      titleMedium: _inter(c, 16, 600, height: 1.4),
      titleSmall: _inter(c, 14, 600, height: 1.4),
      bodyLarge: _inter(c, 16, 400, height: 1.5),
      bodyMedium: _inter(c, 14, 400, height: 1.5),
      bodySmall: _inter(c, 12, 400, height: 1.45),
      labelLarge: _inter(c, 14, 500, height: 1.2, spacing: 0.1),
      labelMedium: _inter(c, 12, 500, height: 1.2, spacing: 0.2),
      labelSmall: _inter(c, 11, 500, height: 1.2, spacing: 0.3),
    );
  }
  static TextStyle _inter(Color color, double size, int weight,
      {double? height, double? spacing, bool tabular = true}) {
    return TextStyle(
      fontFamily: 'Inter',
      color: color,
      fontSize: size,
      height: height,
      letterSpacing: spacing,
      fontWeight: _fw(weight),
      fontVariations: [FontVariation('wght', weight.toDouble())],
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  static TextStyle _tight(Color color, double size, int weight,
      {double? height, double? spacing, bool tabular = true}) {
    return TextStyle(
      fontFamily: 'InterTight',
      color: color,
      fontSize: size,
      height: height,
      letterSpacing: spacing ?? -0.2,
      fontWeight: _fw(weight),
      fontVariations: [FontVariation('wght', weight.toDouble())],
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );
  }

  /// Maps a numeric weight (100..900) to the matching [FontWeight] enum value.
  static FontWeight _fw(int w) => FontWeight.values[(w ~/ 100) - 1];
}
