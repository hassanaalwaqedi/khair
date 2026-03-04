import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0E6E5D);
  static const Color secondary = Color(0xFFD5B26B);
  static const Color background = Color(0xFFF8F4EC);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color textPrimary = Color(0xFF2F3338);
  static const Color textSecondary = Color(0xFF66707C);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onSecondary = Color(0xFF3C2E17);
  static const Color onSurface = Color(0xFF2F3338);

  static const Color success = Color(0xFF2B8A57);
  static const Color error = Color(0xFFBD4337);
  static const Color warning = Color(0xFFD79A2B);
  static const Color info = Color(0xFF2F80ED);
  static const Color disabled = Color(0xFFB8C0CA);

  static const Color border = Color(0xFFE4DED0);
  static const Color divider = Color(0xFFEAE4D8);

  static const Color darkBackground = Color(0xFF121715);
  static const Color darkSurface = Color(0xFF1A211E);
  static const Color darkTextPrimary = Color(0xFFE6E8E7);
  static const Color darkTextSecondary = Color(0xFFB7C0BB);
  static const Color darkBorder = Color(0xFF2C3732);

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    secondary: secondary,
    onSecondary: onSecondary,
    error: error,
    onError: Colors.white,
    surface: surface,
    onSurface: onSurface,
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primary,
    onPrimary: onPrimary,
    secondary: secondary,
    onSecondary: onSecondary,
    error: error,
    onError: Colors.white,
    surface: darkSurface,
    onSurface: darkTextPrimary,
  );
}
