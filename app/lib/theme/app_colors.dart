import 'package:flutter/material.dart';

/// Signa design system color tokens.
/// Based on the "Clinical Curator" theme from Stitch project.
class AppColors {
  AppColors._();

  // Primary
  static const primary = Color(0xFF1D3789);
  static const primaryContainer = Color(0xFF384FA2);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onPrimaryContainer = Color(0xFFBCC7FF);
  static const primaryFixed = Color(0xFFDCE1FF);
  static const primaryFixedDim = Color(0xFFB7C4FF);

  // Secondary
  static const secondary = Color(0xFF555D7F);
  static const secondaryContainer = Color(0xFFCED5FD);
  static const onSecondary = Color(0xFFFFFFFF);
  static const onSecondaryContainer = Color(0xFF545C7E);

  // Tertiary (amber accent — used for Stable badge and warnings)
  static const tertiary = Color(0xFF613200);
  static const tertiaryContainer = Color(0xFF834500);
  static const tertiaryFixed = Color(0xFFFFDCC3);
  static const tertiaryFixedDim = Color(0xFFFFB77D);
  static const onTertiaryFixed = Color(0xFF2F1500);
  static const onTertiaryFixedVariant = Color(0xFF6E3900);
  static const onTertiaryContainer = Color(0xFFFFBC87);

  // Error
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onError = Color(0xFFFFFFFF);
  static const onErrorContainer = Color(0xFF93000A);

  // Surface hierarchy (tonal layering — no borders)
  static const surface = Color(0xFFF8F9FA);
  static const surfaceBright = Color(0xFFF8F9FA);
  static const surfaceDim = Color(0xFFD9DADB);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF3F4F5);
  static const surfaceContainer = Color(0xFFEDEEEF);
  static const surfaceContainerHigh = Color(0xFFE7E8E9);
  static const surfaceContainerHighest = Color(0xFFE1E3E4);
  static const surfaceVariant = Color(0xFFE1E3E4);
  static const surfaceTint = Color(0xFF4259AC);

  // On-surface
  static const onSurface = Color(0xFF191C1D);
  static const onSurfaceVariant = Color(0xFF444651);
  static const outline = Color(0xFF757683);
  static const outlineVariant = Color(0xFFC5C5D3);

  // Status / sparkline colors
  static const statusStableFg = onTertiaryFixed;
  static const statusStableBg = tertiaryFixed;
  static const statusMonitoringFg = onSecondaryContainer;
  static const statusMonitoringBg = secondaryContainer;
  static const statusAlertFg = onErrorContainer;
  static const statusAlertBg = errorContainer;

  // Sparkline accents
  static const sparkGreen = Color(0xFF2E7D32);
  static const sparkAmber = Color(0xFFED6C02);

  // Tinted shadow (signature clinical shadow)
  static Color shadowTint({double opacity = 0.08}) =>
      primary.withOpacity(opacity);
}
