import 'package:flutter/material.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/locale/l10n_extension.dart';

/// Greeting header with quick stats for the student dashboard.
class StatsHeader extends StatelessWidget {
  final String userEmail;
  final int lessonsCompleted;
  final int upcomingCount;
  final int pendingRequests;

  const StatsHeader({
    super.key,
    required this.userEmail,
    required this.lessonsCompleted,
    required this.upcomingCount,
    required this.pendingRequests,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;
    final cardBg = isDark ? KhairColors.darkCard : KhairColors.surface;
    final borderColor = isDark ? KhairColors.darkBorder : KhairColors.border;

    // Extract name from email
    final name = userEmail.split('@').first;
    final displayName = name[0].toUpperCase() + name.substring(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            '${context.l10n.myLearningGreeting}, $displayName 👋',
            style: KhairTypography.h2.copyWith(color: tp),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.myLearningSubtitle,
            style: KhairTypography.bodyMedium.copyWith(color: ts),
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_outline_rounded,
                  value: '$lessonsCompleted',
                  label: context.l10n.lessonsCompleted,
                  color: KhairColors.success,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.schedule_rounded,
                  value: '$upcomingCount',
                  label: context.l10n.upcomingCount,
                  color: KhairColors.primary,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.pending_actions_rounded,
                  value: '$pendingRequests',
                  label: context.l10n.pendingCount,
                  color: KhairColors.warning,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final Color cardBg;
  final Color borderColor;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.cardBg,
    required this.borderColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: KhairTypography.h3.copyWith(
              color: isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: KhairTypography.labelSmall.copyWith(
              color: isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
