import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/locale/l10n_extension.dart';
import '../../../../tokens/tokens.dart';
import '../bloc/notification_bloc.dart';

/// Compact, reusable access point to the authenticated notification center.
///
/// The unread count is selected from the existing NotificationBloc so changes
/// to notifications rebuild only this control, not the surrounding header.
class NotificationBellButton extends StatelessWidget {
  const NotificationBellButton({
    super.key,
    this.color,
    this.onPressed,
  });

  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<NotificationBloc, NotificationState, int>(
      selector: (state) => state.unreadCount,
      builder: (context, unreadCount) {
        final accessibilityLabel = unreadCount > 0
            ? context.l10n.unreadNotificationsCount(unreadCount)
            : context.l10n.notifications;

        return Semantics(
          button: true,
          label: accessibilityLabel,
          child: IconButton(
            tooltip: context.l10n.notifications,
            onPressed: onPressed ?? () => context.go('/notifications'),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.all(10),
            icon: _BellIcon(
              unreadCount: unreadCount,
              color:
                  color ?? IconTheme.of(context).color ?? AppColors.textPrimary,
            ),
          ),
        );
      },
    );
  }
}

class _BellIcon extends StatelessWidget {
  const _BellIcon({required this.unreadCount, required this.color});

  final int unreadCount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final badgeText = unreadCount >= 100 ? '99+' : unreadCount.toString();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.notifications_none_rounded, size: 24, color: color),
        if (unreadCount > 0)
          PositionedDirectional(
            top: -8,
            end: -9,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
              child: Text(
                badgeText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
