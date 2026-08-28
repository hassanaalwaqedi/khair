import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/features/events/domain/entities/event.dart';

void main() {
  test('copyWith can explicitly clear nullable discovery filters', () {
    const active = EventFilter(
      eventType: 'technology',
      searchQuery: 'Hackathon',
      language: 'en',
    );

    final cleared = active.copyWith(
      clearEventType: true,
      clearSearchQuery: true,
      clearLanguage: true,
    );

    expect(cleared.eventType, isNull);
    expect(cleared.searchQuery, isNull);
    expect(cleared.language, isNull);
  });

  test('online and free quick filters are sent to the public events API', () {
    const filter = EventFilter(onlineOnly: true, freeOnly: true);

    expect(filter.toQueryParameters(), containsPair('is_online', 'true'));
    expect(filter.toQueryParameters(), containsPair('free', 'true'));
  });

  test('clearFilters resets quick filters while retaining the chosen city', () {
    const filter = EventFilter(
      city: 'Istanbul',
      onlineOnly: true,
      freeOnly: true,
      dateFilter: DateFilter.today,
    );

    final cleared = filter.clearFilters();

    expect(cleared.city, isNull);
    expect(cleared.onlineOnly, isFalse);
    expect(cleared.freeOnly, isFalse);
    expect(cleared.dateFilter, isNull);
  });
}
