import 'package:khair_app/core/locale/l10n_extension.dart';
import 'package:flutter/material.dart';

/// Empty state widget with illustration and action button
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                icon,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pre-built empty states
class EmptyStates {
  static Widget noEvents(BuildContext context, {VoidCallback? onRefresh}) => EmptyState(
        icon: Icons.event_busy,
        title: context.l10n.noEventsFound1,
        message: context.l10n.adjustFiltersHint,
        actionLabel: onRefresh != null ? context.l10n.tryAgain : null,
        onAction: onRefresh,
      );

  static Widget noSearchResults(BuildContext context, {String? query}) => EmptyState(
        icon: Icons.search_off,
        title: context.l10n.noResults,
        message: context.l10n.adjustFiltersHint,
      );

  static Widget noReports(BuildContext context) => EmptyState(
        icon: Icons.flag_outlined,
        title: context.l10n.noReports,
        message: context.l10n.noReports,
      );

  static Widget noNotifications(BuildContext context) => EmptyState(
        icon: Icons.notifications_none,
        title: context.l10n.noNotifications,
        message: context.l10n.noNotificationsYet,
      );

  static Widget noOrganizers(BuildContext context) => EmptyState(
        icon: Icons.business_outlined,
        title: context.l10n.noOrganizers,
        message: context.l10n.adminNoPendingOrg,
      );

  static Widget noAuditLogs(BuildContext context) => EmptyState(
        icon: Icons.history,
        title: context.l10n.noAuditLogs,
        message: context.l10n.noAuditLogsFound,
      );

  static Widget locationUnavailable(BuildContext context, {VoidCallback? onEnable}) => EmptyState(
        icon: Icons.location_off,
        title: context.l10n.locationUnavailable,
        message: context.l10n.useYourLocation,
        actionLabel: onEnable != null ? context.l10n.useCurrentLocationShort : null,
        onAction: onEnable,
      );
}
