/// A trusted FCM data payload is converted to a typed route. Navigation never
/// depends on localized notification text, so Arabic, English, and Turkish all
/// open the same destination.
class NotificationTarget {
  const NotificationTarget({
    required this.route,
    this.notificationId,
  });

  final String route;
  final String? notificationId;

  static NotificationTarget fromData(Map<String, dynamic> data) {
    final type = _value(data, 'type');
    final notificationId = _value(data, 'notification_id');
    final eventId = _value(data, 'event_id') ?? _value(data, 'entity_id');

    switch (type) {
      case 'event_joined':
      case 'event_join_confirmed':
      case 'event_reminder':
      case 'event_updated':
      case 'event_participant_joined':
      case 'organizer_announcement':
      case 'organizer_message':
      case 'new_participant':
        return NotificationTarget(
          route: _eventRoute(eventId),
          notificationId: notificationId,
        );
      case 'event_cancelled':
        // A cancelled event is no longer guaranteed to be publicly
        // addressable; the authenticated notification center is the reliable
        // destination for its saved details.
        return NotificationTarget(
            route: '/notifications', notificationId: notificationId);
      case 'organizer_approved':
        return NotificationTarget(
            route: '/organizer', notificationId: notificationId);
      case 'organizer_rejected':
      case 'organizer_revision_requested':
        return NotificationTarget(
            route: '/organizer/apply', notificationId: notificationId);
      case 'event_approved':
      case 'event_rejected':
      case 'event_revision_requested':
        return NotificationTarget(
          route: eventId == null
              ? '/organizer/events'
              : '/organizer/events/$eventId',
          notificationId: notificationId,
        );
      case 'verification_review':
        return NotificationTarget(
            route: '/verification', notificationId: notificationId);
      case 'support_reply':
      case 'support_attachment':
      case 'support_message':
        return NotificationTarget(
            route: _supportRoute(_value(data, 'ticket_id')),
            notificationId: notificationId);
      default:
        return NotificationTarget(
            route: '/notifications', notificationId: notificationId);
    }
  }

  static String _eventRoute(String? eventId) =>
      eventId == null || eventId.isEmpty ? '/my-events' : '/events/$eventId';

  static String _supportRoute(String? ticketID) =>
      ticketID == null || ticketID.isEmpty
          ? '/support'
          : '/support?conversation=${Uri.encodeQueryComponent(ticketID)}';

  static String? _value(Map<String, dynamic> data, String key) {
    final value = data[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }
}
