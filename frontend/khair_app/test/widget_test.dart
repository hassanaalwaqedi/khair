import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/features/profile/data/profile_overview_datasource.dart';

void main() {
  test('profile overview maps persisted profile data', () {
    final overview = ProfileOverview.fromJson({
      'user': {
        'email': 'amina@example.com',
        'account_type': 'Member',
        'created_at': '2026-08-13T10:00:00Z',
        'preferred_language': 'tr',
        'display_name': 'Amina Kaya',
      },
      'stats': {
        'saved_events': 2,
        'joined_events': 1,
        'upcoming_events': 1,
        'profile_completion': 60,
      },
      'organizer': {'status': 'pending'},
      'preferences': {
        'push_notifications': true,
        'email_notifications': false,
        'profile_visibility': 'private',
        'language': 'tr',
        'location_label': 'Istanbul, Turkey',
      },
      'upcoming_events': const [],
    });

    expect(overview.user.initials, 'AK');
    expect(overview.stats.savedEvents, 2);
    expect(overview.organizer.status, 'pending');
    expect(overview.preferences.locationLabel, 'Istanbul, Turkey');
  });
}
