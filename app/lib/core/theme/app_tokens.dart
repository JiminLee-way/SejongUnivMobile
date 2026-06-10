import 'package:flutter/material.dart';

/// Sejong Modern Crystal — design tokens ported from DESIGN.md.
class AppColors {
  AppColors._();

  // Surface family
  static const surface = Color(0xFFF7F9FC);
  static const surfaceDim = Color(0xFFD8DADD);
  static const surfaceBright = Color(0xFFF7F9FC);
  static const surfaceContainerLowest = Color(0xFFFFFFFF);
  static const surfaceContainerLow = Color(0xFFF2F4F7);
  static const surfaceContainer = Color(0xFFECEEF1);
  static const surfaceContainerHigh = Color(0xFFE6E8EB);
  static const surfaceContainerHighest = Color(0xFFE0E3E6);
  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF5C403F);

  // Brand (Deep Crimson)
  static const primary = Color(0xFF9E001F);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFC8102E);
  static const onPrimaryContainer = Color(0xFFFFDAD8);
  static const surfaceTint = Color(0xFFBF0229);

  // Secondary / tertiary
  static const secondary = Color(0xFF5F5E5E);
  static const secondaryContainer = Color(0xFFE2DFDE);
  static const onSecondaryContainer = Color(0xFF636262);
  static const outline = Color(0xFF906F6E);
  static const outlineVariant = Color(0xFFE5BDBB);

  // Decorative glass
  static const glassBorder = Color(0x66FFFFFF); // white 40%
  static const glassFill = Color(0xB3F7F9FC); // surface 70%
  static const ambientShadow = Color(
    0x082D3133,
  ); // charcoal 3% — 카드 후광이 너무 어둡지 않게
}

class AppRadius {
  AppRadius._();
  static const sm = 4.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const full = 9999.0;
}

class AppSpacing {
  AppSpacing._();
  static const base = 8.0;
  static const marginMobile = 24.0;
  static const gutterMobile = 16.0;
  static const stackSm = 12.0;
  static const stackMd = 24.0;
  static const stackLg = 48.0;
}
