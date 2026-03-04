import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static const String englishFontFamily = 'Inter';
  static const String arabicFontFamily = 'Cairo';

  static String fontFamilyFor(Locale locale) {
    if (locale.languageCode.toLowerCase() == 'ar') {
      return arabicFontFamily;
    }
    return englishFontFamily;
  }

  static TextTheme textTheme(
    Locale locale, {
    bool isDark = false,
  }) {
    final family = fontFamilyFor(locale);
    final fallback = locale.languageCode.toLowerCase() == 'ar'
        ? const [arabicFontFamily, englishFontFamily, 'sans-serif']
        : const [englishFontFamily, arabicFontFamily, 'sans-serif'];
    final color = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

    TextStyle style(
      double fontSize,
      FontWeight fontWeight,
      double height, {
      double? letterSpacing,
    }) {
      return TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );
    }

    return TextTheme(
      displayLarge: style(56, FontWeight.w700, 1.12, letterSpacing: -0.6),
      headlineLarge: style(40, FontWeight.w700, 1.18, letterSpacing: -0.4),
      headlineMedium: style(32, FontWeight.w600, 1.22, letterSpacing: -0.2),
      titleLarge: style(22, FontWeight.w600, 1.3),
      bodyLarge: style(16, FontWeight.w400, 1.55),
      bodyMedium: style(14, FontWeight.w400, 1.55),
      bodySmall: style(12, FontWeight.w400, 1.5),
      labelLarge: style(14, FontWeight.w600, 1.3, letterSpacing: 0.2),
    );
  }
}
