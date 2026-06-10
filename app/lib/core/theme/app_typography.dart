import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// Typography scale from DESIGN.md.
///
/// Outfit is used for English headings (display/headline) per design system.
/// Pretendard is used for Korean body/label since Outfit lacks Hangul glyphs.
class AppTypography {
  AppTypography._();

  static TextStyle _outfit(
    double size,
    FontWeight weight, {
    double? height,
    double letterSpacing = 0,
  }) {
    return GoogleFonts.outfit(
      fontSize: size,
      fontWeight: weight,
      height: height != null ? height / size : null,
      letterSpacing: letterSpacing,
      color: AppColors.onSurface,
    );
  }

  static TextStyle _pretendard(
    double size,
    FontWeight weight, {
    double? height,
    double letterSpacing = 0,
    Color? color,
  }) {
    return TextStyle(
      fontFamily: 'Pretendard',
      fontSize: size,
      fontWeight: weight,
      height: height != null ? height / size : null,
      letterSpacing: letterSpacing,
      color: color ?? AppColors.onSurface,
    );
  }

  // English / numeric — Outfit
  static TextStyle get displayLg =>
      _outfit(40, FontWeight.w700, height: 48, letterSpacing: -0.8);
  static TextStyle get headlineLg =>
      _outfit(32, FontWeight.w600, height: 40, letterSpacing: -0.32);
  static TextStyle get headlineLgMobile =>
      _pretendard(28, FontWeight.w700, height: 36);
  static TextStyle get headlineMd =>
      _pretendard(20, FontWeight.w600, height: 28);

  // Body — Pretendard handles Korean
  static TextStyle get bodyLg => _pretendard(18, FontWeight.w400, height: 28);
  static TextStyle get bodyMd => _pretendard(16, FontWeight.w400, height: 24);

  // Labels
  static TextStyle get labelMd =>
      _pretendard(14, FontWeight.w500, height: 20, letterSpacing: 0.28);
  static TextStyle get labelSm =>
      _pretendard(12, FontWeight.w600, height: 16, letterSpacing: 0.6);

  // Numeric timer (uses Outfit for tabular feel)
  static TextStyle get timer => GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
    letterSpacing: -0.4,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
