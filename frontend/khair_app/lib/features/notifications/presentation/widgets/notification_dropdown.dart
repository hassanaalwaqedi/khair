import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/khair_theme.dart';
import '../../domain/entities/notification_entity.dart';
import '../bloc/notification_bloc.dart';

/// Notification dropdown overlay with unread badge
class NotificationDropdown extends StatelessWidget {
  const NotificationDropdown({super.key});

  static void show(BuildContext context) {
    final bloc = context.read<NotificationBloc>();
    bloc.add(const LoadNotifications());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _NotificationSheet(),
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
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
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
                  'Notifications',
                  style: KhairTypography.headlineSmall.copyWith(
                    color: isDark
                        ? KhairColors.darkTextPrimary
                        : KhairColors.textPrimary,
                  ),
                ),
                const Spacer(),
                BlocBuilder<NotificationBloc, NotificationState>(
                  buildWhen: (prev, curr) =>
                      prev.unreadCount != curr.unreadCount,
                  builder: (context, state) {
                    if (state.unreadCount == 0) return const SizedBox.shrink();
                    return TextButton(
                      onPressed: () {
                        context
                            .read<NotificationBloc>()
                            .add(const MarkAllNotificationsRead());
                      },
                      child: const Text('Mark all read'),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Flexible(
            child: BlocBuilder<NotificationBloc, NotificationState>(
              builder: (context, state) {
                if (state.status == NotificationStatus.loading) {
                  return const Padding(
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
                        const SizedBox(height: 12),
                        Text(
                          'No Notifications',
                          style: KhairTypography.labelLarge.copyWith(
                            color: isDark
                                ? KhairColors.darkTextPrimary
                                : KhairColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You\'re all caught up!',
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
                  separatorBuilder: (_, __) => const Divider(height: 1),
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          context
              .read<NotificationBloc>()
              .add(MarkNotificationRead(notification.id));
        }
      },
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
            // Unread indicator
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: notification.isRead
                    ? Colors.transparent
                    : KhairColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: KhairTypography.labelMedium.copyWith(
                      color: isDark
                          ? KhairColors.darkTextPrimary
                          : KhairColors.textPrimary,
                      fontWeight:
                          notification.isRead ? FontWeight.w400 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: KhairTypography.bodySmall.copyWith(
                      color: isDark
                          ? KhairColors.darkTextPrimary.withValues(alpha: 0.7)
                          : KhairColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notification.timeAgo,
                    style: KhairTypography.labelSmall.copyWith(
                      color: KhairColors.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
