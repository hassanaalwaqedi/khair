import 'dart:ui';
import 'package:flutter/material.dart';

import '../../core/theme/app_design_system.dart';

// ──────────────────────────────────────────────────────
// SHARED UI COMPONENTS
// Used by Home Page, Create Event, Owner Dashboard, etc.
// ──────────────────────────────────────────────────────

/// Layered gradient scaffold background.
class AppScaffoldBackground extends StatelessWidget {
  final Widget child;
  const AppScaffoldBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.pageBackground),
      child: child,
    );
  }
}

/// Glass-style elevated card.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.borderColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: AppColors.whiteAlpha(0.05),
        borderRadius:
            BorderRadius.circular(borderRadius ?? AppRadius.lg),
        border: Border.all(
          color: borderColor ?? AppColors.whiteAlpha(0.07),
        ),
        boxShadow: boxShadow ?? AppShadows.soft,
      ),
      child: child,
    );
  }
}

/// Glass-effect container with backdrop blur.
class AppGlassContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double blurSigma;

  const AppGlassContainer({
    super.key,
    required this.child,
    this.padding,
    this.blurSigma = 10,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppRadius.cardRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding ?? AppSpacing.cardPadding,
          decoration: BoxDecoration(
            color: AppColors.whiteAlpha(0.06),
            borderRadius: AppRadius.cardRadius,
            border: Border.all(color: AppColors.whiteAlpha(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Unified text input field.
class AppInputField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  const AppInputField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          keyboardType: keyboardType,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
                color: AppColors.whiteAlpha(0.25), fontSize: 13),
            prefixIcon: icon != null
                ? Icon(icon,
                    color: AppColors.whiteAlpha(0.3), size: 20)
                : null,
            filled: true,
            fillColor: AppColors.whiteAlpha(0.05),
            border: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(color: AppColors.whiteAlpha(0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: BorderSide(color: AppColors.whiteAlpha(0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide:
                  const BorderSide(color: AppColors.goldAccent, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.inputRadius,
              borderSide: const BorderSide(color: AppColors.error),
            ),
            counterText: '',
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Unified choice chip.
class AppChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const AppChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppAnimations.normal,
        curve: AppAnimations.defaultCurve,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.whiteAlpha(0.05),
          borderRadius: AppRadius.chipRadius,
          border: Border.all(
            color: isSelected
                ? AppColors.success.withValues(alpha: 0.5)
                : AppColors.whiteAlpha(0.08),
            width: 1.5,
          ),
          boxShadow: isSelected ? AppShadows.emeraldGlow(0.15) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? Colors.white
                      : AppColors.whiteAlpha(0.5)),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : AppColors.whiteAlpha(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Unified primary action button.
class AppPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isGold;

  const AppPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isGold = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isGold ? AppColors.goldAccent : AppColors.primary,
          foregroundColor:
              isGold ? AppColors.emeraldDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          elevation: 0,
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isGold ? AppColors.emeraldDark : Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

/// Unified section title with optional trailing widget.
class AppSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final IconData? icon;

  const AppSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppColors.goldAccent, size: 20),
            const SizedBox(width: 8),
          ],
          Text(title, style: AppTypography.sectionTitle),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Fade + SlideUp entrance animation wrapper.
class AppFadeSlideIn extends StatelessWidget {
  final Widget child;
  final int delayMs;
  final Offset slideOffset;

  const AppFadeSlideIn({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.slideOffset = const Offset(0, 30),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(
          milliseconds: AppAnimations.entrance.inMilliseconds + delayMs),
      curve: AppAnimations.defaultCurve,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(
            slideOffset.dx * (1 - value),
            slideOffset.dy * (1 - value),
          ),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Branded step indicator for multi-step wizards.
class AppStepper extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> labels;
  final List<IconData> icons;
  final void Function(int)? onStepTap;

  const AppStepper({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
    required this.icons,
    this.onStepTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: List.generate(totalSteps, (i) {
          final isActive = i == currentStep;
          final isCompleted = i < currentStep;

          return Expanded(
            child: GestureDetector(
              onTap: () => onStepTap?.call(i),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (i > 0)
                        Expanded(
                          child: AnimatedContainer(
                            duration: AppAnimations.normal,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: isCompleted
                                  ? AppGradients.goldShimmer
                                  : null,
                              color: isCompleted
                                  ? null
                                  : AppColors.whiteAlpha(0.08),
                            ),
                          ),
                        ),
                      AnimatedContainer(
                        duration: AppAnimations.normal,
                        width: isActive ? 38 : 30,
                        height: isActive ? 38 : 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: isCompleted
                              ? AppGradients.emeraldGlow
                              : null,
                          color: isCompleted
                              ? null
                              : isActive
                                  ? AppColors.primary.withValues(alpha: 0.2)
                                  : AppColors.whiteAlpha(0.06),
                          border: isActive
                              ? Border.all(
                                  color: AppColors.goldAccent, width: 2)
                              : null,
                          boxShadow: isActive
                              ? AppShadows.goldGlow(0.15)
                              : null,
                        ),
                        child: Icon(
                          isCompleted
                              ? Icons.check_rounded
                              : icons[i],
                          color: isCompleted || isActive
                              ? Colors.white
                              : AppColors.whiteAlpha(0.3),
                          size: isActive ? 18 : 14,
                        ),
                      ),
                      if (i < totalSteps - 1)
                        Expanded(
                          child: AnimatedContainer(
                            duration: AppAnimations.normal,
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: isCompleted
                                  ? AppGradients.goldShimmer
                                  : null,
                              color: isCompleted
                                  ? null
                                  : AppColors.whiteAlpha(0.08),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : AppColors.whiteAlpha(0.35),
                      fontSize: 10,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
