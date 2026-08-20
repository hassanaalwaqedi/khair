import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/features/events/domain/entities/event.dart';
import 'package:khair_app/features/events/domain/repositories/events_repository.dart';
import 'package:khair_app/features/organizer/presentation/cubit/create_event_cubit.dart';

class _NoopEventsRepository implements EventsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('editing seeds the editor with the selected event rather than a draft',
      () {
    final cubit = CreateEventCubit(_NoopEventsRepository());
    final event = Event(
      id: 'event-42',
      organizerId: 'organizer-1',
      title: 'Community lunch',
      description: 'Meet your neighbours.',
      eventType: 'offline',
      category: 'community',
      startDate: DateTime(2026, 8, 21, 12),
      endDate: DateTime(2026, 8, 21, 14),
      status: 'draft',
      city: 'Istanbul',
      capacity: 30,
      createdAt: DateTime(2026, 8, 1),
      updatedAt: DateTime(2026, 8, 2),
      pricing: const EventPricing(type: 'free'),
    );

    cubit.loadExistingEvent(event);

    expect(cubit.state.draftId, event.id);
    expect(cubit.state.formData.title, event.title);
    expect(cubit.state.formData.description, event.description);
    expect(cubit.state.formData.city, event.city);
    expect(cubit.state.formData.capacity, event.capacity);
    expect(cubit.state.formData.unlimitedCapacity, isFalse);
  });
}
