import 'package:flutter/material.dart';

import '../../tokens/tokens.dart';

ThemeData buildAppTheme({
  required Locale locale,
  Brightness brightness = Brightness.light,
}) {
  final isDark = brightness == Brightness.dark;
  final colorScheme = isDark ? AppColors.darkScheme : AppColors.lightScheme;
  final textTheme = AppTypography.textTheme(locale, isDark: isDark);
  final background =
      isDark ? AppColors.darkBackground : AppColors.background;
  final surface = isDark ? AppColors.darkSurface : AppColors.surface;
  final border = isDark ? AppColors.darkBorder : AppColors.border;
  final secondaryText =
      isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

  final inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(AppRadius.md),
    borderSide: BorderSide(color: border),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    canvasColor: background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: textTheme.titleLarge?.color,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(
          const Size(double.infinity, AppSpacing.x6),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.disabled;
          }
          return AppColors.primary;
        }),
        foregroundColor: WidgetStateProperty.all(AppColors.onPrimary),
        textStyle: WidgetStateProperty.all(textTheme.labelLarge),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        animationDuration: AppDurations.micro,
        elevation: WidgetStateProperty.all(0),
        overlayColor: WidgetStateProperty.all(
          AppColors.onPrimary.withValues(alpha: 0.08),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all(
          const Size(double.infinity, AppSpacing.x6),
        ),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return const BorderSide(color: AppColors.disabled);
          }
          return BorderSide(color: border);
        }),
        foregroundColor: WidgetStateProperty.all(
          isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
        textStyle: WidgetStateProperty.all(textTheme.labelLarge),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        animationDuration: AppDurations.micro,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(AppColors.primary),
        textStyle: WidgetStateProperty.all(textTheme.labelLarge),
        animationDuration: AppDurations.micro,
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
      hintStyle: textTheme.bodyMedium?.copyWith(color: secondaryText),
      labelStyle: textTheme.bodyMedium?.copyWith(color: secondaryText),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x2,
      ),
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.6),
      ),
      focusedErrorBorder: inputBorder.copyWith(
        borderSide: const BorderSide(color: AppColors.error, width: 1.8),
      ),
      border: inputBorder,
    ),
    cardTheme: CardThemeData(
      color: isDark ? AppColors.darkSurfaceElevated : AppColors.surfaceElevated,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: border),
      ),
      elevation: 0,
      shadowColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.surface,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      disabledColor: AppColors.disabled.withValues(alpha: 0.2),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      labelStyle: textTheme.bodySmall!,
      secondaryLabelStyle: textTheme.bodySmall!.copyWith(
        color: AppColors.primary,
      ),
      checkmarkColor: AppColors.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x1,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.background,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
  );
}
