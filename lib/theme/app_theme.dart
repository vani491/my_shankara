// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  // Build a light ColorScheme based on AppColors, overriding key roles explicitly.
  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    error: AppColors.error,
    onError: AppColors.onError,
    outline: AppColors.outline,
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    error: AppColors.error,
    onError: AppColors.onError,
    outline: AppColors.outline,
  );

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _lightScheme,
    scaffoldBackgroundColor: _lightScheme.surface,

    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,

    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.surface.withValues(alpha: 0.25),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.4)),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.4)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primary, width: 1.8),
      ),

      labelStyle: TextStyle(
        color: AppColors.onSurface.withValues(alpha: 0.8),
        fontSize: 15,
      ),

      hintStyle: TextStyle(
        color: AppColors.onSurface.withValues(alpha: 0.6),
        fontSize: 14,
      ),
    ),


    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(
          color: AppColors.accent,
          width: 3,
        ),
      ),
    ),

    textTheme: TextTheme(
      // Big hero / marketing headings
      displayLarge: const TextStyle(),
      displayMedium: const TextStyle(
        color: AppColors.primary,
        fontSize: 32,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
        fontStyle: FontStyle.normal,),
      displaySmall: const TextStyle(),

      // Page / section headings
      headlineLarge: const TextStyle(),
      headlineMedium: const TextStyle(),
      headlineSmall: const TextStyle(
        fontWeight: FontWeight.w600,
        color: AppColors.onBackground,
      ),

      // Titles (app bars, card titles, form titles, etc.)
      titleLarge: const TextStyle(
        color: AppColors.primary,
        fontSize: 30,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: const TextStyle(
        color: AppColors.primary,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        fontStyle: FontStyle.normal,),
      titleSmall: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        fontSize: 18,
        height: 1.2,
      ),

      // Body text
      bodyLarge: const TextStyle(
        color: AppColors.accent,
        fontWeight: FontWeight.w600,
        fontSize: 20,
        height: 1.4,
      ),
      bodyMedium: const TextStyle(
        color: AppColors.accent,
        fontWeight: FontWeight.w400,
        fontSize: 16,
        height: 1.2,
      ),
      bodySmall: const TextStyle(
          color: Colors.white
      ),

      // Labels (buttons, chips, tiny UI text)
      labelLarge: const TextStyle(),
      labelMedium: const TextStyle(),
      labelSmall: const TextStyle(),
    ),

    extensions: [
      BrandExtension(
        accentButton: AppColors.accent,
        surfaceCard: AppColors.surface,
        primary: AppColors.primary,
      ),
    ],


  );


  static final ThemeData dark = light;

}

@immutable
class BrandExtension extends ThemeExtension<BrandExtension> {
  final Color accentButton;
  final Color surfaceCard;
  final Color primary;


  const BrandExtension({
    required this.accentButton,
    required this.surfaceCard,
    required this.primary
  });

  @override
  BrandExtension copyWith({Color? accentButton, Color? surfaceCard}) =>
      BrandExtension(
        accentButton: accentButton ?? this.accentButton,
        surfaceCard: surfaceCard ?? this.surfaceCard,
        primary: AppColors.primary,
      );

  @override
  BrandExtension lerp(ThemeExtension<BrandExtension>? other, double t) {
    if (other is! BrandExtension) return this;
    return BrandExtension(
      accentButton: Color.lerp(accentButton, other.accentButton, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
    );
  }
}
