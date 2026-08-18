import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/core/utils/calendar_service.dart';
import 'package:khair_app/features/events/domain/entities/event.dart';

void main() {
  group('CalendarService.buildGoogleCalendarUrl', () {
    test('generates correct URL for an online event with a meeting link', () {
      final event = Event(
        id: 'evt-123',
        organizerId: 'org-456',
        title: 'SQL & Vector Database',
        eventType: 'online',
        startDate: DateTime.utc(2026, 8, 21, 17, 0, 0),
        endDate: DateTime.utc(2026, 8, 21, 18, 0, 0),
        description: 'An awesome event about SQL.',
        organizerName: 'Tech Group',
        onlinePlatform: 'Google Meet',
        isOnline: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'published',
      );

      final url = CalendarService.buildGoogleCalendarUrl(
          event, 'https://meet.google.com/abc-defg-hij');
      final uri = Uri.parse(url);

      expect(uri.scheme, 'https');
      expect(uri.host, 'calendar.google.com');
      expect(uri.path, '/calendar/render');
      
      final params = uri.queryParameters;
      expect(params['action'], 'TEMPLATE');
      expect(params['text'], 'SQL & Vector Database');
      expect(params['dates'], '20260821T170000Z/20260821T180000Z');
      expect(params['location'], 'Google Meet');
      
      final details = params['details']!;
      expect(details, contains('An awesome event about SQL.'));
      expect(details, contains('Organizer: Tech Group'));
      expect(details, contains('/events/evt-123'));
      expect(details, contains('https://meet.google.com/abc-defg-hij'));
    });

    test('generates correct URL for in-person event without meeting link', () {
      final event = Event(
        id: 'evt-789',
        organizerId: 'org-456',
        title: 'محاضرة الذكاء الاصطناعي', // Arabic title
        eventType: 'in-person',
        startDate: DateTime.utc(2026, 12, 1, 10, 30, 0),
        endDate: DateTime.utc(2026, 12, 1, 12, 30, 0),
        description: 'Turkish characters: İşğüçöı',
        venueName: 'Istanbul Center',
        city: 'Istanbul',
        country: 'Turkey',
        isOnline: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'published',
      );

      final url = CalendarService.buildGoogleCalendarUrl(event, null);
      final uri = Uri.parse(url);
      final params = uri.queryParameters;

      expect(params['text'], 'محاضرة الذكاء الاصطناعي');
      expect(params['dates'], '20261201T103000Z/20261201T123000Z');
      expect(params['location'], 'Istanbul Center, Istanbul, Turkey');
      
      final details = params['details']!;
      expect(details, contains('İşğüçöı'));
      expect(details, isNot(contains('Join meeting:')));
    });

    test('omits meeting URL when authorizedMeetingUrl is null', () {
      final event = Event(
        id: 'evt-111',
        organizerId: 'org-222',
        title: 'Secret Event',
        eventType: 'online',
        startDate: DateTime.utc(2026, 1, 1, 0, 0, 0),
        isOnline: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        status: 'published',
      );

      final url = CalendarService.buildGoogleCalendarUrl(event, null);
      final params = Uri.parse(url).queryParameters;

      // End date should default to 1 hour after start
      expect(params['dates'], '20260101T000000Z/20260101T010000Z');
      expect(params['details'], isNot(contains('Join meeting:')));
    });
  });
}
