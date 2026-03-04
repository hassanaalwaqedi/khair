import 'package:flutter/material.dart';

import '../tokens/tokens.dart';
import 'status_badge.dart';

class EventCard extends StatelessWidget {
  final String title;
  final String organization;
  final String dateTimeLabel;
  final String locationLabel;
  final String? categoryLabel;
  final StatusBadgeType badgeType;
  final String? badgeLabel;
  final VoidCallback? onTap;
  final Widget? trailing;

  const EventCard({
    super.key,
    required this.title,
    required this.organization,
    required this.dateTimeLabel,
    required this.locationLabel,
    this.categoryLabel,
    this.badgeType = StatusBadgeType.neutral,
    this.badgeLabel,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.x2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (categoryLabel != null) ...[
                          StatusBadge(
                            label: categoryLabel!,
                            compact: true,
                          ),
                          const SizedBox(height: AppSpacing.x1),
                        ],
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: AppSpacing.x2),
                    trailing!,
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              _MetaLine(
                icon: Icons.verified_user_outlined,
                text: organization,
              ),
              const SizedBox(height: AppSpacing.x1),
              _MetaLine(
                icon: Icons.schedule_rounded,
                text: dateTimeLabel,
              ),
              const SizedBox(height: AppSpacing.x1),
              _MetaLine(
                icon: Icons.place_outlined,
                text: locationLabel,
              ),
              if (badgeLabel != null) ...[
                const SizedBox(height: AppSpacing.x2),
                StatusBadge(
                  label: badgeLabel!,
                  type: badgeType,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: AppSpacing.x2,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.x1),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}
