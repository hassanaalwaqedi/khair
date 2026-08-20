import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/core/push/notification_target.dart';

void main() {
  group('NotificationTarget', () {
    test('routes event notifications using payload IDs, not display text', () {
      final target = NotificationTarget.fromData({
        'type': 'event_updated',
        'event_id': 'event-123',
        'notification_id': 'notification-123',
      });

      expect(target.route, '/events/event-123');
      expect(target.notificationId, 'notification-123');
    });

    test('opens notification center for a cancelled event', () {
      final target = NotificationTarget.fromData({
        'type': 'event_cancelled',
        'event_id': 'event-123',
        'notification_id': 'notification-123',
      });

      expect(target.route, '/notifications');
      expect(target.notificationId, 'notification-123');
    });

    test('routes organizer decisions to their correct destinations', () {
      expect(
        NotificationTarget.fromData({'type': 'organizer_approved'}).route,
        '/organizer',
      );
      expect(
        NotificationTarget.fromData({'type': 'organizer_revision_requested'})
            .route,
        '/organizer/apply',
      );
      expect(
        NotificationTarget.fromData({
          'type': 'event_rejected',
          'entity_id': 'event-123',
        }).route,
        '/organizer/events/event-123',
      );
    });

    test('opens the exact support conversation from a support reply', () {
      final target = NotificationTarget.fromData({
        'type': 'support_reply',
        'ticket_id': 'conversation-123',
      });

      expect(target.route, '/support?conversation=conversation-123');
    });

    test('falls back to the notification center for unknown types', () {
      expect(
        NotificationTarget.fromData({'type': 'future_notification_type'}).route,
        '/notifications',
      );
    });
  });
}
