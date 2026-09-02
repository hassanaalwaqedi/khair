import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/khair_theme.dart';
import '../../../../core/widgets/khair_brand.dart';
import '../../domain/entities/notification_entity.dart';
import '../bloc/notification_bloc.dart';
import '../notification_presentation.dart';
import '../widgets/notification_detail_sheet.dart';

class NotificationCenterPage extends StatelessWidget {
  const NotificationCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide the singleton NotificationBloc for this page
    return BlocProvider.value(
      value: getIt<NotificationBloc>()..add(LoadNotifications()),
      child: _NotificationCenterView(),
    );
  }
}

class _NotificationCenterView extends StatelessWidget {
  const _NotificationCenterView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Color(0xFF0F0F1E) : Color(0xFFF5F5F8),
      appBar: AppBar(
        backgroundColor: isDark ? Color(0xFF1A1A2E) : Colors.white,
        elevation: 0,
        title: BlocBuilder<NotificationBloc, NotificationState>(
          buildWhen: (prev, curr) => prev.unreadCount != curr.unreadCount,
          builder: (context, state) {
            return Row(
              children: [
                Icon(Icons.notifications_rounded,
                    color: KhairColors.primary, size: 24),
                SizedBox(width: 8),
                Text(
                  state.unreadCount > 0
                      ? '${context.l10n.notifications} (${state.unreadCount})'
                      : context.l10n.notifications,
                  style: KhairTypography.headlineSmall.copyWith(
                    color: isDark ? Colors.white : KhairColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.notificationSettings,
            onPressed: () => context.push('/notification-settings'),
            icon: const Icon(Icons.tune_rounded),
          ),
          BlocBuilder<NotificationBloc, NotificationState>(
            buildWhen: (prev, curr) => prev.unreadCount != curr.unreadCount,
            builder: (context, state) {
              if (state.unreadCount == 0) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => context
                    .read<NotificationBloc>()
                    .add(MarkAllNotificationsRead()),
                icon: Icon(Icons.done_all_rounded, size: 18),
                label: Text(context.l10n.readAll),
                style: TextButton.styleFrom(
                  foregroundColor: KhairColors.primary,
                ),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state.status == NotificationStatus.loading &&
              state.notifications.isEmpty) {
            return Center(
              child: CircularProgressIndicator(color: KhairColors.primary),
            );
          }

          if (state.status == NotificationStatus.failure &&
              state.notifications.isEmpty) {
            return _buildErrorState(context, isDark, state.errorMessage);
          }

          if (state.notifications.isEmpty) {
            return _buildEmptyState(context, isDark);
          }

          return RefreshIndicator(
            color: KhairColors.primary,
            onRefresh: () async {
              context.read<NotificationBloc>().add(LoadNotifications());
              await context.read<NotificationBloc>().stream.firstWhere(
                    (s) => s.status != NotificationStatus.loading,
                  );
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: state.notifications.length,
              itemBuilder: (context, index) => _buildNotificationCard(
                context,
                state.notifications[index],
                isDark,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: KhairColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded,
                size: 40, color: KhairColors.primary.withValues(alpha: 0.5)),
          ),
          SizedBox(height: 16),
          Text(
            context.l10n.noNotificationsYet,
            style: KhairTypography.labelLarge.copyWith(
              color: isDark ? Colors.white70 : KhairColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            context.l10n.notificationsAllCaughtUp,
            style: KhairTypography.bodySmall.copyWith(
              color: KhairColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark, String? error) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline_rounded,
                size: 40, color: Colors.red.withValues(alpha: 0.5)),
          ),
          SizedBox(height: 16),
          Text(
            context.l10n.failedToLoadNotifications,
            style: KhairTypography.labelLarge.copyWith(
              color: isDark ? Colors.white70 : KhairColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            error ?? context.l10n.tryAgain1,
            style: KhairTypography.bodySmall.copyWith(
              color: KhairColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () =>
                context.read<NotificationBloc>().add(LoadNotifications()),
            icon: Icon(Icons.refresh_rounded, size: 18),
            label: Text(context.l10n.retry),
            style: ElevatedButton.styleFrom(
              backgroundColor: KhairColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotification notif,
    bool isDark,
  ) {
    final presentation = NotificationPresentationResolver.resolve(
      notif,
      context.l10n,
      Localizations.localeOf(context),
    );
    final receivedAt = NotificationPresentationResolver.formatReceivedAt(
      notif.createdAt,
      context.l10n,
      Localizations.localeOf(context),
    );

    return Dismissible(
      key: ValueKey('notification-${notif.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsetsDirectional.only(end: 20),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.red),
      ),
      onDismissed: (_) =>
          context.read<NotificationBloc>().add(DeleteNotification(notif.id)),
      child: Semantics(
        button: true,
        label:
            '${presentation.title}. ${notif.isRead ? '' : context.l10n.notificationUnread}',
        child: GestureDetector(
          onTap: () => _openNotification(context, notif, isDark),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? (notif.isRead ? Color(0xFF1A1A2E) : Color(0xFF1E2A3A))
                  : (notif.isRead
                      ? Colors.white
                      : KhairColors.primary.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: notif.isRead
                    ? (isDark
                        ? Colors.white10
                        : Colors.grey.withValues(alpha: 0.15))
                    : KhairColors.primary.withValues(alpha: 0.2),
                width: notif.isRead ? 0.5 : 1,
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Khair logo avatar
                _KhairAvatar(isRead: notif.isRead),
                SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sender label
                      Text(
                        'Khair',
                        style: KhairTypography.labelSmall.copyWith(
                          color: KhairColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        presentation.title,
                        style: KhairTypography.labelMedium.copyWith(
                          fontWeight:
                              notif.isRead ? FontWeight.w500 : FontWeight.w700,
                          color:
                              isDark ? Colors.white : KhairColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        presentation.body,
                        style: KhairTypography.bodySmall.copyWith(
                          color: isDark
                              ? Colors.white60
                              : KhairColors.textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (presentation.metadata.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Row(
                            children: [
                              Icon(
                                presentation.metadata.first.icon,
                                size: 13,
                                color: KhairColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  presentation.metadata.first.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: KhairTypography.labelSmall.copyWith(
                                    color: KhairColors.textTertiary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded,
                              size: 12, color: KhairColors.textTertiary),
                          SizedBox(width: 4),
                          Text(
                            receivedAt ?? '',
                            style: KhairTypography.labelSmall.copyWith(
                              color: KhairColors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark ? Colors.white30 : Colors.grey[400],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Unread dot
                if (!notif.isRead) ...[
                  SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: KhairColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: KhairColors.primary.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openNotification(
    BuildContext context,
    AppNotification notif,
    bool isDark,
  ) {
    if (!notif.isRead) {
      context.read<NotificationBloc>().add(MarkNotificationRead(notif.id));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationDetailSheet(notification: notif),
    );
  }
}

// ─── Khair Logo Avatar ─────────────────────────

class _KhairAvatar extends StatelessWidget {
  final bool isRead;
  const _KhairAvatar({required this.isRead});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isRead ? .56 : 1,
      child: KhairBrandMark(size: 42, decorative: true),
    );
  }
}
