import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/locale/l10n_extension.dart';

/// Card for a sheikh the student has interacted with.
class SheikhCard extends StatelessWidget {
  final Map<String, dynamic> sheikh;

  const SheikhCard({super.key, required this.sheikh});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeName = Localizations.localeOf(context).toString();
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts =
        isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;
    final cardBg = isDark ? KhairColors.darkCard : KhairColors.surface;
    final borderColor = isDark ? KhairColors.darkBorder : KhairColors.border;

    final sheikhId = sheikh['sheikh_id'] as String? ?? '';
    final displayName = sheikh['display_name'] as String?;
    final email = sheikh['email'] as String? ?? '';
    final avatarUrl = sheikh['avatar_url'] as String?;
    final specialization = sheikh['specialization'] as String?;
    final totalLessons = sheikh['total_lessons'] as int? ?? 0;
    final lastLessonStr = sheikh['last_lesson_date'] as String?;

    final fallbackName = context.l10n.sheikhDefaultName;
    final emailName = email.split('@').first.trim();
    final name = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : (emailName.isNotEmpty ? emailName : fallbackName);
    DateTime? lastLesson;
    if (lastLessonStr != null) lastLesson = DateTime.tryParse(lastLessonStr);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Sheikh info row
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: KhairColors.primary.withValues(alpha: 0.1),
                backgroundImage:
                    avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        name[0].toUpperCase(),
                        style: TextStyle(
                          color: KhairColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: KhairTypography.labelLarge.copyWith(
                        color: tp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (specialization != null && specialization.isNotEmpty)
                      Text(
                        specialization,
                        style: KhairTypography.bodySmall.copyWith(color: ts),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.school_rounded, size: 12, color: ts),
                        const SizedBox(width: 4),
                        Text(
                          '$totalLessons ${context.l10n.lessonsLabel}',
                          style: KhairTypography.bodySmall
                              .copyWith(color: ts, fontSize: 11),
                        ),
                        if (lastLesson != null) ...[
                          Text(' · ',
                              style: TextStyle(color: ts, fontSize: 11)),
                          Text(
                            DateFormat.MMMd(localeName)
                                .format(lastLesson.toLocal()),
                            style: KhairTypography.bodySmall
                                .copyWith(color: ts, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/conversations'),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: Text(context.l10n.sendMessage,
                      style: const TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(
                      color: KhairColors.primary.withValues(alpha: 0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => context.push(
                    '/sheikhs/$sheikhId/book?name=${Uri.encodeComponent(name)}',
                  ),
                  icon: const Icon(Icons.calendar_today_rounded, size: 14),
                  label: Text(context.l10n.bookAgain,
                      style: const TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KhairColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
