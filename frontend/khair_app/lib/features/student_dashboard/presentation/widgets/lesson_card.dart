import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/locale/l10n_extension.dart';

/// Card for displaying a lesson (upcoming or past).
class LessonCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isUpcoming;
  final VoidCallback? onCancel;
  final VoidCallback? onRate;

  const LessonCard({
    super.key,
    required this.booking,
    this.isUpcoming = true,
    this.onCancel,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts = isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;
    final cardBg = isDark ? KhairColors.darkCard : KhairColors.surface;
    final borderColor = isDark ? KhairColors.darkBorder : KhairColors.border;

    final sheikhName = booking['sheikh_name'] as String? ?? 'Sheikh';
    final status = (booking['status'] as String?) ?? 'pending';
    final startStr = booking['start_time'] as String?;
    final meetingLink = booking['meeting_link'] as String?;
    final platform = booking['meeting_platform'] as String?;

    DateTime? startTime;
    if (startStr != null) {
      startTime = DateTime.tryParse(startStr);
    }

    final dateStr = startTime != null
        ? DateFormat('EEE, MMM d').format(startTime.toLocal())
        : '—';
    final timeStr = startTime != null
        ? DateFormat('h:mm a').format(startTime.toLocal())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top: Sheikh name + status badge
          Row(
            children: [
              // Sheikh avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: KhairColors.primary.withValues(alpha: 0.1),
                child: Text(
                  sheikhName[0].toUpperCase(),
                  style: TextStyle(
                    color: KhairColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sheikhName,
                      style: KhairTypography.labelLarge.copyWith(
                        color: tp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$dateStr · $timeStr',
                      style: KhairTypography.bodySmall.copyWith(color: ts),
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),

          // Platform info
          if (platform != null && platform.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  platform.toLowerCase().contains('zoom')
                      ? Icons.videocam_rounded
                      : Icons.video_call_rounded,
                  size: 14,
                  color: ts,
                ),
                const SizedBox(width: 4),
                Text(
                  platform,
                  style: KhairTypography.bodySmall.copyWith(color: ts),
                ),
              ],
            ),
          ],

          // Actions
          const SizedBox(height: 10),
          Row(
            children: [
              if (isUpcoming && meetingLink != null && meetingLink.isNotEmpty)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.videocam_rounded,
                    label: context.l10n.joinLesson,
                    color: KhairColors.success,
                    onTap: () => _openLink(meetingLink),
                  ),
                ),
              if (isUpcoming && meetingLink != null && meetingLink.isNotEmpty)
                const SizedBox(width: 8),
              if (isUpcoming && onCancel != null)
                _ActionButton(
                  icon: Icons.close_rounded,
                  label: context.l10n.cancelLesson,
                  color: KhairColors.error,
                  outlined: true,
                  onTap: onCancel!,
                ),
              if (!isUpcoming && onRate != null)
                Expanded(
                  child: _ActionButton(
                    icon: Icons.star_rounded,
                    label: context.l10n.rateSheikh,
                    color: KhairColors.warning,
                    onTap: onRate!,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'confirmed':
        bgColor = KhairColors.successLight;
        textColor = KhairColors.successDark;
        label = context.l10n.statusConfirmed;
        break;
      case 'pending':
        bgColor = KhairColors.warningLight;
        textColor = KhairColors.warningDark;
        label = context.l10n.statusPending;
        break;
      case 'rejected':
        bgColor = KhairColors.errorLight;
        textColor = KhairColors.errorDark;
        label = context.l10n.statusRejected;
        break;
      case 'completed':
        bgColor = KhairColors.infoLight;
        textColor = KhairColors.infoDark;
        label = context.l10n.statusCompleted;
        break;
      default:
        bgColor = KhairColors.neutral100;
        textColor = KhairColors.neutral600;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14, color: color),
        label: Text(
          label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 0,
      ),
    );
  }
}
