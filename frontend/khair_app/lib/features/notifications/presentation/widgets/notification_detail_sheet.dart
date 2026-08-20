import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:khair_app/core/theme/khair_theme.dart';
import 'package:khair_app/core/widgets/khair_brand.dart';

import '../../domain/entities/notification_entity.dart';
import '../notification_presentation.dart';

/// Shared in-app notification detail surface for the full list and compact
/// notification overlay. Structured records get localized metadata and an
/// entity CTA; legacy records keep their stored title/body unchanged.
class NotificationDetailSheet extends StatelessWidget {
  final AppNotification notification;

  const NotificationDetailSheet({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final presentation = NotificationPresentationResolver.resolve(
      notification,
      context.l10n,
      Localizations.localeOf(context),
    );
    final receivedAt = NotificationPresentationResolver.formatReceivedAt(
      notification.createdAt,
      context.l10n,
      Localizations.localeOf(context),
    );

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                child: Row(
                  children: [
                    const KhairBrandMark(size: 48, decorative: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Khair',
                            semanticsLabel: 'Khair',
                            style: KhairTypography.headlineSmall.copyWith(
                              color: KhairColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          if (receivedAt != null)
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded,
                                    size: 13, color: KhairColors.textTertiary),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    receivedAt,
                                    style: KhairTypography.labelSmall.copyWith(
                                      color: KhairColors.textTertiary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: context.l10n.notificationClose,
                      child: IconButton(
                        tooltip: context.l10n.notificationClose,
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.close_rounded,
                            color: isDark ? Colors.white54 : Colors.grey[500]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                color: isDark ? Colors.white10 : Colors.grey[200],
                height: 1,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Semantics(
                  header: true,
                  label: presentation.title,
                  child: Text(
                    presentation.title,
                    style: KhairTypography.h2.copyWith(
                      color: isDark ? Colors.white : KhairColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Semantics(
                  label: presentation.body,
                  child: Text(
                    presentation.body,
                    style: KhairTypography.bodyLarge.copyWith(
                      color:
                          isDark ? Colors.white70 : KhairColors.textSecondary,
                      height: 1.7,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              if (!notification.isRead)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Semantics(
                    label: context.l10n.notificationUnread,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: KhairColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.notificationUnread,
                          style: KhairTypography.labelSmall.copyWith(
                            color: KhairColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (presentation.metadata.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    children: presentation.metadata
                        .map((row) => _MetadataRow(row: row, isDark: isDark))
                        .toList(),
                  ),
                ),
              if (presentation.hasAction)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  child: Semantics(
                    button: true,
                    label: presentation.ctaLabel,
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final eventId = presentation.eventId;
                          if (eventId == null) return;
                          Navigator.pop(context);
                          context.push('/events/$eventId');
                        },
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(presentation.ctaLabel!),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: KhairColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  final NotificationMetadataRow row;
  final bool isDark;

  const _MetadataRow({required this.row, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(row.icon, size: 19, color: KhairColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              row.text,
              style: KhairTypography.bodyMedium.copyWith(
                color: isDark ? Colors.white70 : KhairColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
