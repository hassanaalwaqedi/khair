import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/locale/l10n_extension.dart';

/// Card for displaying a lesson request with status.
class RequestCard extends StatelessWidget {
  final Map<String, dynamic> request;

  const RequestCard({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localeName = Localizations.localeOf(context).toString();
    final tp = isDark ? KhairColors.darkTextPrimary : KhairColors.textPrimary;
    final ts =
        isDark ? KhairColors.darkTextSecondary : KhairColors.textSecondary;
    final cardBg = isDark ? KhairColors.darkCard : KhairColors.surface;
    final borderColor = isDark ? KhairColors.darkBorder : KhairColors.border;

    final sheikhName =
        (request['sheikh_name'] as String?)?.trim().isNotEmpty == true
            ? (request['sheikh_name'] as String).trim()
            : context.l10n.sheikhDefaultName;
    final status = (request['status'] as String?) ?? 'pending';
    final message = request['message'] as String? ?? '';
    final rejectionReason = request['rejection_reason'] as String?;
    final createdStr = request['created_at'] as String?;
    final preferredTimeStr = request['preferred_time'] as String?;

    DateTime? createdAt;
    if (createdStr != null) createdAt = DateTime.tryParse(createdStr);

    DateTime? preferredTime;
    if (preferredTimeStr != null) {
      preferredTime = DateTime.tryParse(preferredTimeStr);
    }

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
          // Top: Sheikh name + status
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: KhairColors.info.withValues(alpha: 0.1),
                child: Text(
                  sheikhName[0].toUpperCase(),
                  style: TextStyle(
                    color: KhairColors.info,
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
                    if (createdAt != null)
                      Text(
                        DateFormat.yMMMd(localeName)
                            .format(createdAt.toLocal()),
                        style: KhairTypography.bodySmall.copyWith(color: ts),
                      ),
                  ],
                ),
              ),
              _RequestStatusBadge(status: status),
            ],
          ),

          // Message
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message,
              style: KhairTypography.bodyMedium.copyWith(color: ts),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // Preferred time
          if (preferredTime != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: ts),
                const SizedBox(width: 4),
                Text(
                  DateFormat.MMMEd(localeName)
                      .add_jm()
                      .format(preferredTime.toLocal()),
                  style: KhairTypography.bodySmall.copyWith(color: ts),
                ),
              ],
            ),
          ],

          // Rejection reason
          if (status == 'rejected' &&
              rejectionReason != null &&
              rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: KhairColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: KhairColors.errorDark),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      rejectionReason,
                      style: TextStyle(
                        fontSize: 12,
                        color: KhairColors.errorDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestStatusBadge extends StatelessWidget {
  final String status;

  const _RequestStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'accepted':
        bgColor = KhairColors.successLight;
        textColor = KhairColors.successDark;
        label = context.l10n.statusAccepted;
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
      case 'scheduled':
        bgColor = KhairColors.infoLight;
        textColor = KhairColors.infoDark;
        label = context.l10n.statusScheduled;
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
