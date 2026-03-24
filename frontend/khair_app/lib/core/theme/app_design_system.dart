import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────
// APP DESIGN SYSTEM — Single source of truth
// Blue primary + neutral surfaces + Islamic green identity
// ─────────────────────────────────────────────────

/// Unified color palette for the entire app.
class AppColors {
  AppColors._();

  // ── Primary Blue ──
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);
  static const Color primarySurface = Color(0xFFEFF6FF); // blue-50

  // ── Islamic Identity (Green — limited use) ──
  static const Color islamicGreen = Color(0xFF16A34A);
  static const Color islamicGreenLight = Color(0xFFDCFCE7);
  static const Color islamicGreenDark = Color(0xFF166534);

  // ── Semantic ──
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Dark Surface Layers ──
  static const Color surfaceBase = Color(0xFF0B0F14);
  static const Color surfaceElevated = Color(0xFF111827);
  static const Color surfaceHigh = Color(0xFF1F2937);
  static const Color surfaceHighest = Color(0xFF374151);

  // ── Light Surface Layers ──
  static const Color lightSurfaceBase = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFF6F7F8);

  // ── Text on dark ──
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);

  // ── Light Text ──
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextMuted = Color(0xFF9CA3AF);

  // ── Borders ──
  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF374151);

  // ── Legacy compatibility aliases ──
  // (mapped to new blue/neutral palette until all usages are migrated)
  static const Color goldAccent = primary;
  static const Color emeraldDark = primaryDark;

  // ── White / Black Alpha helpers ──
  static Color whiteAlpha(double a) => Colors.white.withValues(alpha: a);
  static Color blackAlpha(double a) => Colors.black.withValues(alpha: a);

  // ── Theme-aware helpers ──
  static Color surfaceColor(BuildContext context, [double elevation = 0.05]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? whiteAlpha(elevation) : blackAlpha(elevation * 0.5);
  }

  static Color borderColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? borderDark : borderLight;
  }

  static Color onSurfaceColor(BuildContext context, [double alpha = 1.0]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: alpha)
        : Colors.black.withValues(alpha: alpha);
  }

  static Color onSurfaceMutedColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? textSecondary : lightTextSecondary;
  }
}

/// Unified gradients.
class AppGradients {
  AppGradients._();

  // ── Hero backgrounds ──
  static const LinearGradient heroBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0B0F14),
      Color(0xFF111827),
      Color(0xFF1E293B),
      Color(0xFF111827),
    ],
  );

  static const LinearGradient heroBackgroundLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1D4ED8),
      Color(0xFF2563EB),
      Color(0xFF3B82F6),
      Color(0xFF2563EB),
    ],
  );

  // ── Page backgrounds ──
  static const LinearGradient pageBackground = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF111827),
      Color(0xFF0B0F14),
    ],
  );

  static const LinearGradient pageBackgroundLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF6F7F8),
    ],
  );

  static LinearGradient pageBackgroundOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? pageBackground
        : pageBackgroundLight;
  }

  static LinearGradient heroBackgroundOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? heroBackground
        : heroBackgroundLight;
  }

  // ── Accent gradients ──
  static const LinearGradient primaryGlow = LinearGradient(
    colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF3B82F6)],
  );

  static const LinearGradient goldShimmer = LinearGradient(
    colors: [Color(0xFFD5B26B), Color(0xFFE8D98F)],
  );

  // ── Islamic gradient (limited use) ──
  static const LinearGradient islamicGradient = LinearGradient(
    colors: [Color(0xFF166534), Color(0xFF16A34A), Color(0xFF22C55E)],
  );

  // Legacy compatibility aliases
  static const LinearGradient emeraldGlow = primaryGlow;
}

/// Unified border radius.
class AppRadius {
  AppRadius._();

  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double pill = 100;

  // Common BorderRadius
  static final BorderRadius cardRadius = BorderRadius.circular(lg);
  static final BorderRadius inputRadius = BorderRadius.circular(md);
  static final BorderRadius buttonRadius = BorderRadius.circular(18);
  static final BorderRadius chipRadius = BorderRadius.circular(xl);
}

/// Unified shadows.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get medium => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> primaryGlow([double intensity = 0.2]) => [
        BoxShadow(
          color: const Color(0xFF2563EB).withValues(alpha: intensity),
          blurRadius: 12,
        ),
      ];

  // Legacy compatibility aliases
  static List<BoxShadow> emeraldGlow([double intensity = 0.2]) =>
      primaryGlow(intensity);

  static List<BoxShadow> goldGlow([double intensity = 0.1]) => [
        BoxShadow(
          color: const Color(0xFFD5B26B).withValues(alpha: intensity),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
}

/// Unified spacing scale.
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Common EdgeInsets
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  static const EdgeInsets cardPadding = EdgeInsets.all(20);
  static const EdgeInsets sectionSpacing = EdgeInsets.only(bottom: 28);
}

/// Unified animation constants.
class AppAnimations {
  AppAnimations._();

  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  static const Duration entrance = Duration(milliseconds: 600);

  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve bouncyCurve = Curves.easeOutBack;
}

/// Unified typography.
class AppTypography {
  AppTypography._();

  static const TextStyle heroTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );
}
