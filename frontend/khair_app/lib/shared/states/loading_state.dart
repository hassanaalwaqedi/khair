import 'package:flutter/material.dart';

import '../../tokens/tokens.dart';

class LoadingState extends StatelessWidget {
  final String? message;
  final double? minHeight;

  const LoadingState({
    super.key,
    this.message,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: minHeight,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: AppSpacing.x4,
                height: AppSpacing.x4,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpacing.x2),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
