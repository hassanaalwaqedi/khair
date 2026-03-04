import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

enum StatusBadgeType {
  success,
  error,
  warning,
  info,
  neutral,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final StatusBadgeType type;
  final bool compact;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = StatusBadgeType.neutral,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForType(type);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.x1 : AppSpacing.x2,
        vertical: compact ? AppSpacing.x1 / 2 : AppSpacing.x1,
      ),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: colors.$2),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.$3,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  (Color, Color, Color) _colorsForType(StatusBadgeType type) {
    switch (type) {
      case StatusBadgeType.success:
        return (
          AppColors.success.withValues(alpha: 0.12),
          AppColors.success.withValues(alpha: 0.3),
          AppColors.success,
        );
      case StatusBadgeType.error:
        return (
          AppColors.error.withValues(alpha: 0.12),
          AppColors.error.withValues(alpha: 0.3),
          AppColors.error,
        );
      case StatusBadgeType.warning:
        return (
          AppColors.warning.withValues(alpha: 0.14),
          AppColors.warning.withValues(alpha: 0.35),
          AppColors.warning,
        );
      case StatusBadgeType.info:
        return (
          AppColors.info.withValues(alpha: 0.12),
          AppColors.info.withValues(alpha: 0.3),
          AppColors.info,
        );
      case StatusBadgeType.neutral:
        return (
          AppColors.surface,
          AppColors.border,
          AppColors.textSecondary,
        );
    }
  }
}
