import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData dark() => _base(
    brightness: Brightness.dark,
    surface: AppColors.black,
    onSurface: AppColors.snow,
    card: AppColors.charcoal,
  );

  static ThemeData light() => _base(
    brightness: Brightness.light,
    surface: AppColors.snow,
    onSurface: AppColors.charcoal,
    card: const Color(0xFFF4F3EF),
  );

  static ThemeData _base({
    required Brightness brightness,
    required Color surface,
    required Color onSurface,
    required Color card,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.gold,
      onPrimary: AppColors.black,
      secondary: AppColors.emerald,
      onSecondary: AppColors.black,
      error: AppColors.ruby,
      onError: AppColors.snow,
      surface: surface,
      onSurface: onSurface,
      surfaceContainer: card,
      surfaceContainerHighest: AppColors.graphite,
      outline: AppColors.matteGray,
      outlineVariant: AppColors.graphite,
      shadow: Colors.transparent,
      scrim: Colors.black54,
      inverseSurface: onSurface,
      onInverseSurface: surface,
      inversePrimary: AppColors.oldGold,
      tertiary: AppColors.gold,
      onTertiary: AppColors.black,
      primaryContainer: AppColors.graphite,
      onPrimaryContainer: onSurface,
      secondaryContainer: AppColors.graphite,
      onSecondaryContainer: onSurface,
      tertiaryContainer: AppColors.graphite,
      onTertiaryContainer: onSurface,
      errorContainer: AppColors.ruby,
      onErrorContainer: AppColors.snow,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      dividerColor: AppColors.graphite,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          side: const BorderSide(color: AppColors.gold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.snow
                : onSurface,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.graphite
                : Colors.transparent,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.snow
                : onSurface,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.matteGray),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: AppColors.graphite,
        disabledColor: AppColors.matteGray.withValues(alpha: 0.25),
        labelStyle: TextStyle(color: onSurface),
        secondaryLabelStyle: const TextStyle(color: AppColors.snow),
        side: const BorderSide(color: AppColors.matteGray),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        showCheckmark: false,
        checkmarkColor: AppColors.snow,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme.copyWith(
        headlineMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(color: onSurface, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: onSurface, height: 1.4),
        bodyMedium: TextStyle(
          color: onSurface.withValues(alpha: 0.78),
          height: 1.4,
        ),
      ),
    );
  }
}
