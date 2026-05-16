import 'package:flutter/material.dart';

/// FlexCourt design system — typography scale.
class AppTypography {
  AppTypography._();

  static const String _fontFamily = 'Roboto';

  static TextStyle get displayLarge => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      );

  static TextStyle get displayMedium => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get displaySmall => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get headlineLarge => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get headlineMedium => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get headlineSmall => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleLarge => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleMedium => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleSmall => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get bodyLarge => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyMedium => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodySmall => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get labelLarge => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get labelMedium => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get labelSmall => const TextStyle(
        fontFamily: _fontFamily,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      );
}
