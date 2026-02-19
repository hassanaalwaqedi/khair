import 'package:flutter/material.dart';

/// Khair Design System - Colors
/// A calm, trustworthy palette for a global Muslim-focused platform
class KhairColors {
  KhairColors._();

  // Primary - Calm Green (Trust, Growth, Islam)
  static const Color primary = Color(0xFF2E7D5A);
  static const Color primaryLight = Color(0xFF4CAF7D);
  static const Color primaryDark = Color(0xFF1B5E3C);
  static const Color primarySurface = Color(0xFFE8F5EE);

  // Secondary - Warm Gold (Premium, Excellence)
  static const Color secondary = Color(0xFFD4A84B);
  static const Color secondaryLight = Color(0xFFE8C97F);
  static const Color secondaryDark = Color(0xFFB8922F);

  // Accent
  static const Color accent = Color(0xFF22D3EE);
  static const Color accentLight = Color(0xFFCFFAFE);

  // Neutral Scale (100–900)
  static const Color neutral50 = Color(0xFFFAFBFC);
  static const Color neutral100 = Color(0xFFF5F7F9);
  static const Color neutral200 = Color(0xFFEEF1F4);
  static const Color neutral300 = Color(0xFFE5E9ED);
  static const Color neutral400 = Color(0xFFCBD2D9);
  static const Color neutral500 = Color(0xFF8C939B);
  static const Color neutral600 = Color(0xFF5C6670);
  static const Color neutral700 = Color(0xFF3D4752);
  static const Color neutral800 = Color(0xFF1A1F26);
  static const Color neutral900 = Color(0xFF0D1117);

  // Light Theme Surfaces
  static const Color background = Color(0xFFFAFBFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF5F7F9);
  static const Color border = Color(0xFFE5E9ED);
  static const Color divider = Color(0xFFEEF1F4);

  // Dark Theme Surfaces (no pure black — dark gray scale)
  static const Color darkBackground = Color(0xFF0F1419);
  static const Color darkSurface = Color(0xFF1A1F26);
  static const Color darkSurfaceVariant = Color(0xFF252D38);
  static const Color darkCard = Color(0xFF1E2732);
  static const Color darkBorder = Color(0xFF2F3A46);
  static const Color darkDivider = Color(0xFF2F3A46);

  // Text
  static const Color textPrimary = Color(0xFF1A1F26);
  static const Color textSecondary = Color(0xFF5C6670);
  static const Color textTertiary = Color(0xFF8C939B);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Dark Text
  static const Color darkTextPrimary = Color(0xFFF0F3F6);
  static const Color darkTextSecondary = Color(0xFF9BA4AE);
  static const Color darkTextTertiary = Color(0xFF6B7580);

  // Semantic
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF166534);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color warningDark = Color(0xFF92400E);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFF991B1B);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF1E40AF);

  // Verification badge
  static const Color verified = Color(0xFF0EA5E9);
  static const Color verifiedLight = Color(0xFFE0F2FE);
}

/// Khair Design System - Typography
class KhairTypography {
  KhairTypography._();

  static const String fontFamily = 'Inter';
  static const String headingFontFamily = 'Poppins';
  static const String arabicFontFamily = 'Cairo';
  static const String arabicBodyFontFamily = 'IBMPlexSansArabic';

  // H1 – 32px / bold
  static const TextStyle h1 = TextStyle(
    fontFamily: headingFontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.5,
    color: KhairColors.textPrimary,
  );

  // H2 – 24px / semibold
  static const TextStyle h2 = TextStyle(
    fontFamily: headingFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.25,
    color: KhairColors.textPrimary,
  );

  // H3 – 20px / medium
  static const TextStyle h3 = TextStyle(
    fontFamily: headingFontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: KhairColors.textPrimary,
  );

  // Display
  static const TextStyle displayLarge = TextStyle(
    fontFamily: headingFontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -1,
    color: KhairColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: headingFontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
    color: KhairColors.textPrimary,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: headingFontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: KhairColors.textPrimary,
  );

  // Headings (alias to match Material naming)
  static const TextStyle headlineLarge = h2;
  static const TextStyle headlineMedium = h3;

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: headingFontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: KhairColors.textPrimary,
  );

  // Body – 16px
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.6,
    color: KhairColors.textPrimary,
  );

  // Small – 14px
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: KhairColors.textSecondary,
  );

  // Caption – 12px
  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: KhairColors.textTertiary,
  );

  // Labels
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.1,
    color: KhairColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.2,
    color: KhairColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    letterSpacing: 0.3,
    color: KhairColors.textTertiary,
  );

  // Button
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.2,
  );
}

/// Khair Design System - Spacing (4px base scale)
class KhairSpacing {
  KhairSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double smd = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  // Responsive padding
  static EdgeInsets get pagePadding => const EdgeInsets.symmetric(horizontal: 24);
  static EdgeInsets get cardPadding => const EdgeInsets.all(16);
  static EdgeInsets get sectionPadding => const EdgeInsets.symmetric(vertical: 48);
}

/// Khair Design System - Border Radius
class KhairRadius {
  KhairRadius._();

  static const double xs = 4;
  static const double sm = 6;    // sm: 6px as per spec
  static const double md = 12;   // md: 12px as per spec
  static const double lg = 20;   // lg: 20px as per spec
  static const double xl = 24;
  static const double full = 999;

  static BorderRadius get small => BorderRadius.circular(sm);
  static BorderRadius get medium => BorderRadius.circular(md);
  static BorderRadius get large => BorderRadius.circular(lg);
  static BorderRadius get extraLarge => BorderRadius.circular(xl);
}

/// Khair Design System - Shadows (soft subtle only)
class KhairShadows {
  KhairShadows._();

  static List<BoxShadow> get sm => [
    BoxShadow(
      color: Colors.black.withAlpha(8),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get md => [
    BoxShadow(
      color: Colors.black.withAlpha(10),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get lg => [
    BoxShadow(
      color: Colors.black.withAlpha(12),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // Elevated hover state
  static List<BoxShadow> get hover => [
    BoxShadow(
      color: Colors.black.withAlpha(16),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];
}

/// Khair Design System - Animation Durations
class KhairAnimations {
  KhairAnimations._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration pageTransition = Duration(milliseconds: 300);

  static const Curve defaultCurve = Curves.easeInOut;
  static const Curve entranceCurve = Curves.easeOut;
  static const Curve exitCurve = Curves.easeIn;
}

/// Khair Theme Data - Light + Dark
class KhairTheme {
  KhairTheme._();

  // ───────────── LIGHT THEME ─────────────
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    fontFamily: KhairTypography.fontFamily,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: KhairColors.primary,
      brightness: Brightness.light,
      primary: KhairColors.primary,
      secondary: KhairColors.secondary,
      tertiary: KhairColors.accent,
      surface: KhairColors.surface,
      error: KhairColors.error,
    ),
    scaffoldBackgroundColor: KhairColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: KhairColors.surface,
      foregroundColor: KhairColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: KhairTypography.headlineSmall,
    ),
    cardTheme: CardThemeData(
      color: KhairColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: KhairRadius.medium,
        side: const BorderSide(color: KhairColors.border),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: KhairColors.primary,
        foregroundColor: KhairColors.textOnPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: KhairRadius.medium,
        ),
        textStyle: KhairTypography.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KhairColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        side: const BorderSide(color: KhairColors.primary),
        shape: RoundedRectangleBorder(
          borderRadius: KhairRadius.medium,
        ),
        textStyle: KhairTypography.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KhairColors.primary,
        textStyle: KhairTypography.button,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KhairColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: KhairRadius.medium,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: KhairRadius.medium,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: KhairRadius.medium,
        borderSide: const BorderSide(color: KhairColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: KhairRadius.medium,
        borderSide: const BorderSide(color: KhairColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: KhairTypography.bodyMedium.copyWith(
        color: KhairColors.textTertiary,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: KhairColors.surfaceVariant,
      selectedColor: KhairColors.primarySurface,
      labelStyle: KhairTypography.labelMedium,
      shape: RoundedRectangleBorder(
        borderRadius: KhairRadius.small,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    dividerTheme: const DividerThemeData(
      color: KhairColors.divider,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: KhairColors.neutral800,
      contentTextStyle: KhairTypography.bodyMedium.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: KhairRadius.medium),
      elevation: 4,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );

  // ───────────── DARK THEME ─────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    fontFamily: KhairTypography.fontFamily,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: KhairColors.primary,
      brightness: Brightness.dark,
      primary: KhairColors.primaryLight,
      secondary: KhairColors.secondaryLight,
      tertiary: KhairColors.accent,
      surface: KhairColors.darkSurface,
      error: KhairColors.error,
    ),
    scaffoldBackgroundColor: KhairColors.darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: KhairColors.darkSurface,
      foregroundColor: KhairColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: KhairTypography.headlineSmall.copyWith(
        color: KhairColors.darkTextPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: KhairColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: KhairRadius.medium,
        side: const BorderSide(color: KhairColors.darkBorder),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: KhairColors.primaryLight,
        foregroundColor: KhairColors.neutral900,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: KhairRadius.medium,
        ),
        textStyle: KhairTypography.button,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: KhairColors.primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        side: const BorderSide(color: KhairColors.primaryLight),
        shape: RoundedRectangleBorder(
          borderRadius: KhairRadius.medium,
        ),
        textStyle: KhairTypography.button,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: KhairColors.primaryLight,
        textStyle: KhairTypography.button,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: KhairColors.darkSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: KhairRadius.medium,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: KhairRadius.medium,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: KhairRadius.medium,
        borderSide: const BorderSide(color: KhairColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: KhairRadius.medium,
        borderSide: const BorderSide(color: KhairColors.error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: KhairTypography.bodyMedium.copyWith(
        color: KhairColors.darkTextTertiary,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: KhairColors.darkSurfaceVariant,
      selectedColor: KhairColors.primaryDark.withAlpha(100),
      labelStyle: KhairTypography.labelMedium.copyWith(
        color: KhairColors.darkTextSecondary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: KhairRadius.small,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),
    dividerTheme: const DividerThemeData(
      color: KhairColors.darkDivider,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: KhairColors.neutral300,
      contentTextStyle: KhairTypography.bodyMedium.copyWith(color: KhairColors.neutral900),
      shape: RoundedRectangleBorder(borderRadius: KhairRadius.medium),
      elevation: 4,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
