import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/features/profile/data/profile_overview_datasource.dart';

void main() {
  group('ProfileOverview', () {
    test('parses the canonical lowercase user field', () {
      final overview = ProfileOverview.fromJson(_payload('user'));

      expect(overview.user.email, 'member@example.com');
      expect(overview.user.accountType, 'Member');
      expect(overview.upcomingEvents, isEmpty);
    });

    test('accepts the legacy capitalized User field during rollout', () {
      final overview = ProfileOverview.fromJson(_payload('User'));

      expect(overview.user.email, 'member@example.com');
    });

    test('rejects a response without user data', () {
      final payload = _payload('user')..remove('user');

      expect(
        () => ProfileOverview.fromJson(payload),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

Map<String, dynamic> _payload(String userKey) => {
      userKey: {
        'email': 'member@example.com',
        'account_type': 'Member',
        'created_at': '2026-08-13T13:15:18.86538Z',
        'preferred_language': 'en',
      },
      'stats': {
        'saved_events': 0,
        'joined_events': 0,
        'upcoming_events': 0,
        'profile_completion': 20,
      },
      'organizer': {'status': 'none'},
      'preferences': {
        'push_notifications': true,
        'email_notifications': true,
        'profile_visibility': 'private',
        'language': 'en',
        'location_label': 'Not set',
      },
      'upcoming_events': null,
    };
