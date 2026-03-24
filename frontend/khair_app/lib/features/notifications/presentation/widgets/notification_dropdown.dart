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
    Future.delayed(const Duration(milliseconds: 200), () {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => _NotificationDetailDialog(
            notification: notification,
            isDark: isDark,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetail(context),
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
            // Khair branded avatar
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: notification.isRead
                      ? [Colors.grey[400]!, Colors.grey[500]!]
                      : [KhairColors.primary, const Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'K',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 2),
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
                  Row(
                    children: [
                      Text(
                        notification.timeAgo,
                        style: KhairTypography.labelSmall.copyWith(
                          color: KhairColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
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
    );
  }
}

// ─── Notification Detail Dialog ──────────────────

class _NotificationDetailDialog extends StatelessWidget {
  final AppNotification notification;
  final bool isDark;

  const _NotificationDetailDialog({
    required this.notification,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Khair branding
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [KhairColors.primary, Color(0xFF2E7D32)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: KhairColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'K',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Khair',
                            style: KhairTypography.headlineSmall.copyWith(
                              color: KhairColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 13, color: KhairColors.textTertiary),
                              const SizedBox(width: 4),
                              Text(
                                notification.timeAgo,
                                style: KhairTypography.labelSmall.copyWith(
                                  color: KhairColors.textTertiary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded,
                          color: isDark ? Colors.white54 : Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                color: isDark ? Colors.white10 : Colors.grey[200],
                height: 1,
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Text(
                  notification.title,
                  style: KhairTypography.h2.copyWith(
                    color: isDark ? Colors.white : KhairColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Full message
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Text(
                  notification.message,
                  style: KhairTypography.bodyLarge.copyWith(
                    color: isDark ? Colors.white70 : KhairColors.textSecondary,
                    height: 1.7,
                    fontSize: 15,
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
