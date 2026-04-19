import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  /// Typography scale — Manrope for display/headline, Inter for body/label.
  static TextTheme textTheme() {
    final manrope = GoogleFonts.manropeTextTheme();
    final inter = GoogleFonts.interTextTheme();
    return TextTheme(
      displayLarge: manrope.displayLarge?.copyWith(
          fontWeight: FontWeight.w800, color: AppColors.onSurface),
      displayMedium: manrope.displayMedium?.copyWith(
          fontSize: 44,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface),
      headlineLarge: manrope.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700, color: AppColors.primaryContainer),
      headlineMedium: manrope.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700, color: AppColors.primaryContainer),
      headlineSmall: manrope.headlineSmall?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryContainer),
      titleLarge: manrope.titleLarge?.copyWith(
          fontWeight: FontWeight.w700, color: AppColors.onSurface),
      titleMedium: inter.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurface),
      titleSmall: inter.titleSmall?.copyWith(
          fontWeight: FontWeight.w600, color: AppColors.onSurface),
      bodyLarge: inter.bodyLarge?.copyWith(color: AppColors.onSurfaceVariant),
      bodyMedium: inter.bodyMedium?.copyWith(
          fontSize: 14, color: AppColors.onSurfaceVariant),
      bodySmall: inter.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
      labelLarge: inter.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      labelMedium: inter.labelMedium?.copyWith(
          fontWeight: FontWeight.w700, color: AppColors.outline),
      labelSmall: inter.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.outline),
    );
  }

  /// Uppercase "label" style used throughout the design (tracking-widest).
  static TextStyle labelUppercase({Color? color, double size = 10}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
        color: color ?? AppColors.outline,
        textBaseline: TextBaseline.alphabetic,
      );

  static TextStyle displayNumber({Color? color, double size = 36}) =>
      GoogleFonts.manrope(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color ?? AppColors.onSurface,
      );

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryContainer,
        onPrimary: AppColors.onPrimary,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondary: AppColors.onSecondary,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        error: AppColors.error,
        errorContainer: AppColors.errorContainer,
        onError: AppColors.onError,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      textTheme: textTheme(),
      splashFactory: InkSparkle.splashFactory,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: AppColors.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          elevation: 0,
          shadowColor: AppColors.shadowTint(opacity: 0.12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryContainer,
          side:
              BorderSide(color: AppColors.primaryContainer.withOpacity(0.4), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
