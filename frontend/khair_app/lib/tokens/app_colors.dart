import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Primary Accent (Blue) ──
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Secondary (Gold — premium feel) ──
  static const Color secondary = Color(0xFFD5B26B);
  static const Color onSecondary = Color(0xFF3C2E17);

  // ── Islamic Identity (Green — limited use) ──
  static const Color islamicGreen = Color(0xFF16A34A);
  static const Color islamicGreenLight = Color(0xFFDCFCE7);
  static const Color islamicGreenDark = Color(0xFF166534);

  // ── Light Theme Surfaces ──
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF6F7F8);
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // ── Dark Theme Surfaces ──
  static const Color darkBackground = Color(0xFF0B0F14);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceElevated = Color(0xFF1F2937);
  static const Color darkBorder = Color(0xFF374151);
  static const Color darkDivider = Color(0xFF1F2937);

  // ── Text (Light) ──
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color onSurface = Color(0xFF111827);

  // ── Text (Dark) ──
  static const Color darkTextPrimary = Color(0xFFF9FAFB);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkTextTertiary = Color(0xFF6B7280);

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
    onPrimary: Color(0xFF0B0F14),
    secondary: secondary,
    onSecondary: onSecondary,
    error: error,
    onError: Colors.white,
    surface: darkSurface,
    onSurface: darkTextPrimary,
  );
}
