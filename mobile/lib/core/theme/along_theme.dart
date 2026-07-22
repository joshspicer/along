import 'package:flutter/material.dart';

abstract final class AlongColors {
  static const teal = Color(0xFF0B6B61);
  static const tealDark = Color(0xFF61C7B8);
  static const coral = Color(0xFFB94F46);
  static const coralDark = Color(0xFFFF9C91);
  static const sun = Color(0xFFA66B00);
  static const sunDark = Color(0xFFF5C65B);
  static const daylight = Color(0xFFF7FAF9);
  static const nightGlass = Color(0xFF101816);
  static const graphite = Color(0xFF17201E);
  static const paleTeal = Color(0xFFDDEFEA);
}

abstract final class AlongTheme {
  static ThemeData light() => _build(
    brightness: Brightness.light,
    primary: AlongColors.teal,
    onPrimary: Colors.white,
    secondary: AlongColors.coral,
    tertiary: AlongColors.sun,
    surface: AlongColors.daylight,
    onSurface: AlongColors.graphite,
  );

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    primary: AlongColors.tealDark,
    onPrimary: AlongColors.nightGlass,
    secondary: AlongColors.coralDark,
    tertiary: AlongColors.sunDark,
    surface: AlongColors.nightGlass,
    onSurface: const Color(0xFFEDF5F2),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color onPrimary,
    required Color secondary,
    required Color tertiary,
    required Color surface,
    required Color onSurface,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      tertiary: tertiary,
      surface: surface,
      onSurface: onSurface,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
    );
    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
          fontSize: 50,
          height: 1,
          fontWeight: FontWeight.w700,
          letterSpacing: -2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.12,
          letterSpacing: -0.8,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 18,
          height: 1.5,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 16,
          height: 1.45,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          base.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}
