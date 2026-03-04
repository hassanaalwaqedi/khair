import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Widget? leading;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.leading,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize:
            Size(expand ? double.infinity : 0, AppSpacing.buttonHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        animationDuration: AppDurations.micro,
      ),
      child: AnimatedSwitcher(
        duration: AppDurations.micro,
        switchInCurve: AppCurves.standard,
        switchOutCurve: AppCurves.standard,
        child: isLoading
            ? const SizedBox(
                key: ValueKey('loading'),
                width: AppSpacing.x3,
                height: AppSpacing.x3,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.onPrimary),
                ),
              )
            : Row(
                key: const ValueKey('content'),
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: AppSpacing.x1),
                  ],
                  Text(label),
                ],
              ),
      ),
    );

    if (expand) {
      return button;
    }
    return IntrinsicWidth(child: button);
  }
}
