import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../../../core/widgets/khair_brand.dart';
import '../../domain/entities/notification_entity.dart';
import '../bloc/notification_bloc.dart';
import '../notification_presentation.dart';
import 'notification_detail_sheet.dart';

/// Notification dropdown overlay with unread badge
class NotificationDropdown extends StatelessWidget {
  const NotificationDropdown({super.key});

  static void show(BuildContext context) {
    final bloc = context.read<NotificationBloc>();
    bloc.add(LoadNotifications());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: _NotificationSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: isDark ? Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                Text(
                  context.l10n.notifications,
                  style: KhairTypography.headlineSmall.copyWith(
                    color: isDark
                        ? KhairColors.darkTextPrimary
                        : KhairColors.textPrimary,
                  ),
                ),
                Spacer(),
                BlocBuilder<NotificationBloc, NotificationState>(
                  buildWhen: (prev, curr) =>
                      prev.unreadCount != curr.unreadCount,
                  builder: (context, state) {
                    if (state.unreadCount == 0) return const SizedBox.shrink();
                    return TextButton(
                      onPressed: () {
                        context
                            .read<NotificationBloc>()
                            .add(MarkAllNotificationsRead());
                      },
                      child: Text(context.l10n.markAllRead),
                    );
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1),
          // Content
          Flexible(
            child: BlocBuilder<NotificationBloc, NotificationState>(
              builder: (context, state) {
                if (state.status == NotificationStatus.loading) {
                  return Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: KhairColors.primary,
                      ),
                    ),
                  );
                }

                if (state.notifications.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 48,
                          color: KhairColors.textTertiary,
                        ),
                        SizedBox(height: 12),
                        Text(
                          context.l10n.noNotifications,
                          style: KhairTypography.labelLarge.copyWith(
                            color: isDark
                                ? KhairColors.darkTextPrimary
                                : KhairColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          context.l10n.notificationsAllCaughtUp,
                          style: KhairTypography.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: state.notifications.length,
                  separatorBuilder: (_, __) => Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notification = state.notifications[index];
                    return _NotificationTile(
                      notification: notification,
                      isDark: isDark,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;

  const _NotificationTile({
    required this.notification,
    required this.isDark,
  });

  void _openDetail(BuildContext context) {
    // Mark as read
    if (!notification.isRead) {
      context
          .read<NotificationBloc>()
          .add(MarkNotificationRead(notification.id));
    }

    // Close the dropdown first, then show the detail dialog
    Navigator.pop(context);

    // Use a short delay to let the dropdown close before opening the dialog
    Future.delayed(Duration(milliseconds: 200), () {
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => NotificationDetailSheet(notification: notification),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final presentation = NotificationPresentationResolver.resolve(
      notification,
      context.l10n,
      Localizations.localeOf(context),
    );

    return InkWell(
      onTap: () => _openDetail(context),
      child: Semantics(
        button: true,
        label:
            '${presentation.title}. ${notification.isRead ? '' : context.l10n.notificationUnread}',
        child: Container(
          color: notification.isRead
              ? Colors.transparent
              : (isDark
                  ? KhairColors.primary.withValues(alpha: 0.08)
                  : KhairColors.primarySurface.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Opacity(
                opacity: notification.isRead ? .56 : 1,
                child: KhairBrandMark(size: 38, decorative: true),
              ),
              SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Khair',
                      style: KhairTypography.labelSmall.copyWith(
                        color: KhairColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                        letterSpacing: 0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      presentation.title,
                      style: KhairTypography.labelMedium.copyWith(
                        color: isDark
                            ? KhairColors.darkTextPrimary
                            : KhairColors.textPrimary,
                        fontWeight: notification.isRead
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      presentation.body,
                      style: KhairTypography.bodySmall.copyWith(
                        color: isDark
                            ? KhairColors.darkTextPrimary.withValues(alpha: 0.7)
                            : KhairColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          notification.timeAgo,
                          style: KhairTypography.labelSmall.copyWith(
                            color: KhairColors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                        Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: isDark ? Colors.white30 : Colors.grey[400],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Unread dot
              if (!notification.isRead)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: KhairColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: KhairColors.primary.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
