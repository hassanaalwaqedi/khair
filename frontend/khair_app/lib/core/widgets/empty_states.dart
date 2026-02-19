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
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
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
  static Widget noEvents({VoidCallback? onRefresh}) => EmptyState(
        icon: Icons.event_busy,
        title: 'No Events Found',
        message: 'There are no events matching your criteria. Try adjusting your filters or check back later.',
        actionLabel: onRefresh != null ? 'Refresh' : null,
        onAction: onRefresh,
      );

  static Widget noSearchResults({String? query}) => EmptyState(
        icon: Icons.search_off,
        title: 'No Results',
        message: query != null 
            ? 'No events found for "$query". Try a different search term.'
            : 'No results found. Try adjusting your search.',
      );

  static Widget noReports() => const EmptyState(
        icon: Icons.flag_outlined,
        title: 'No Reports',
        message: 'There are no pending reports to review.',
      );

  static Widget noNotifications() => const EmptyState(
        icon: Icons.notifications_none,
        title: 'No Notifications',
        message: "You're all caught up! Check back later for updates.",
      );

  static Widget noOrganizers() => const EmptyState(
        icon: Icons.business_outlined,
        title: 'No Organizers',
        message: 'No organizers pending approval.',
      );

  static Widget noAuditLogs() => const EmptyState(
        icon: Icons.history,
        title: 'No Audit Logs',
        message: 'No actions have been logged yet.',
      );

  static Widget locationUnavailable({VoidCallback? onEnable}) => EmptyState(
        icon: Icons.location_off,
        title: 'Location Unavailable',
        message: 'Enable location services to see events near you.',
        actionLabel: onEnable != null ? 'Enable Location' : null,
        onAction: onEnable,
      );
}
