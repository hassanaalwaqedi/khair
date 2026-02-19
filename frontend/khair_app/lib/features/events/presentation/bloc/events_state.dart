part of 'events_bloc.dart';

enum EventsStatus { initial, loading, loadingMore, success, failure }

class EventsState extends Equatable {
  final EventsStatus status;
  final EventsStatus detailsStatus;
  final EventsStatus nearbyStatus;
  final EventsStatus createStatus;
  final List<Event> events;
  final List<Event> nearbyEvents;
  final Event? selectedEvent;
  final EventFilter filter;
  final bool hasReachedMax;
  final String? errorMessage;

  const EventsState({
    this.status = EventsStatus.initial,
    this.detailsStatus = EventsStatus.initial,
    this.nearbyStatus = EventsStatus.initial,
    this.createStatus = EventsStatus.initial,
    this.events = const [],
    this.nearbyEvents = const [],
    this.selectedEvent,
    this.filter = const EventFilter(),
    this.hasReachedMax = false,
    this.errorMessage,
  });

  EventsState copyWith({
    EventsStatus? status,
    EventsStatus? detailsStatus,
    EventsStatus? nearbyStatus,
    EventsStatus? createStatus,
    List<Event>? events,
    List<Event>? nearbyEvents,
    Event? selectedEvent,
    EventFilter? filter,
    bool? hasReachedMax,
    String? errorMessage,
  }) {
    return EventsState(
      status: status ?? this.status,
      detailsStatus: detailsStatus ?? this.detailsStatus,
      nearbyStatus: nearbyStatus ?? this.nearbyStatus,
      createStatus: createStatus ?? this.createStatus,
      events: events ?? this.events,
      nearbyEvents: nearbyEvents ?? this.nearbyEvents,
      selectedEvent: selectedEvent ?? this.selectedEvent,
      filter: filter ?? this.filter,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        detailsStatus,
        nearbyStatus,
        createStatus,
        events,
        nearbyEvents,
        selectedEvent,
        filter,
        hasReachedMax,
        errorMessage,
      ];
}
