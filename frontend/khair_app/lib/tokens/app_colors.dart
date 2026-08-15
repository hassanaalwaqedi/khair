import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary Accent (Blue) ──
  static const Color primary = Color(0xFFF43F75);
  static const Color primaryLight = Color(0xFFFF7AA2);
  static const Color primaryDark = Color(0xFFE63268);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Secondary (Gold — premium feel) ──
  static const Color secondary = Color(0xFFC75A7C);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // ── Islamic Identity (Green — limited use) ──
  static const Color islamicGreen = Color(0xFF16A34A);
  static const Color islamicGreenLight = Color(0xFFDCFCE7);
  static const Color islamicGreenDark = Color(0xFF166534);

  // ── Light Theme Surfaces ──
  static const Color background = Color(0xFFFCFAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE8E3E7);
  static const Color divider = Color(0xFFF5EFF2);

  // ── Dark Theme Surfaces ──
  static const Color darkBackground = Color(0xFF101014);
  static const Color darkSurface = Color(0xFF19181E);
  static const Color darkSurfaceElevated = Color(0xFF211F26);
  static const Color darkBorder = Color(0xFF302D35);
  static const Color darkDivider = Color(0xFF242129);

  // ── Text (Light) ──
  static const Color textPrimary = Color(0xFF171126);
  static const Color textSecondary = Color(0xFF726B7B);
  static const Color textTertiary = Color(0xFF9B94A0);
  static const Color onSurface = Color(0xFF171126);

  // ── Text (Dark) ──
  static const Color darkTextPrimary = Color(0xFFF8F6F8);
  static const Color darkTextSecondary = Color(0xFFC8C1CA);
  static const Color darkTextTertiary = Color(0xFF938B96);

  // ── Semantic ──
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color disabled = Color(0xFFD1D5DB);

  // ── Color Schemes ──
  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: onPrimary,
    secondary: secondary,
    onSecondary: onSecondary,
    error: error,
    onError: Colors.white,
    surface: background,
    onSurface: onSurface,
  );

  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: primaryLight,
    onPrimary: Color(0xFF101014),
    secondary: secondary,
    onSecondary: onSecondary,
    error: error,
    onError: Colors.white,
    surface: darkSurface,
    onSurface: darkTextPrimary,
  );
}
