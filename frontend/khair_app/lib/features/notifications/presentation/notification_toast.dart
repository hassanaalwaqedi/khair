import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/router/app_router.dart' as router_lib;
import '../../../core/di/injection.dart';
import '../../../core/locale/l10n_extension.dart';
import '../../../tokens/tokens.dart';
import '../domain/entities/notification_entity.dart';
import 'bloc/notification_bloc.dart';
import 'notification_presentation.dart';

/// Lightweight in-app toast for foreground notifications. It lives in the
/// root overlay, so it never covers a form's submit controls and works across
/// desktop, tablet, and mobile layouts.
class NotificationToast {
  NotificationToast._();

  static final Set<String> _shown = <String>{};
  static OverlayEntry? _entry;

  static void show(AppNotification notification) {
    final key = notification.id.isNotEmpty
        ? notification.id
        : '${notification.notificationType}:${notification.title}:${notification.message}';
    if (_shown.contains(key)) return;
    _shown.add(key);
    Timer(const Duration(minutes: 2), () => _shown.remove(key));

    final context = router_lib.rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final overlay = Navigator.of(context, rootNavigator: true).overlay;
    if (overlay == null) return;
    _entry?.remove();

    final presentation = NotificationPresentationResolver.resolve(
      notification,
      context.l10n,
      Localizations.localeOf(context),
    );
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: isRtl ? 16 : null,
        right: isRtl ? null : 16,
        width: (MediaQuery.of(context).size.width * .9).clamp(280.0, 420.0),
        child: _ToastCard(
          presentation: presentation,
          onClose: () {
            entry.remove();
            if (identical(_entry, entry)) _entry = null;
          },
          onTap: () {
            entry.remove();
            if (identical(_entry, entry)) _entry = null;
            getIt<NotificationBloc>().add(
              MarkNotificationRead(notification.id),
            );
            router_lib.appRouter.go(notification.routePath);
          },
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    Timer(const Duration(seconds: 6), () {
      if (entry.mounted) {
        entry.remove();
        if (identical(_entry, entry)) _entry = null;
      }
    });
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.presentation,
    required this.onClose,
    required this.onTap,
  });

  final NotificationPresentation presentation;
  final VoidCallback onClose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Card(
        elevation: 10,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: AppColors.primary.withValues(alpha: .28),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.primarySoft,
                  child: Icon(
                    Icons.notifications_active_outlined,
                    color: AppColors.primary,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        presentation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        presentation.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.notificationClose,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 19),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
