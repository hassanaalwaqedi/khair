part of 'events_bloc.dart';

abstract class EventsEvent extends Equatable {
  const EventsEvent();

  @override
  List<Object?> get props => [];
}

class LoadEvents extends EventsEvent {}

class RefreshEvents extends EventsEvent {}

class LoadMoreEvents extends EventsEvent {}

class UpdateFilter extends EventsEvent {
  final EventFilter filter;

  const UpdateFilter(this.filter);

  @override
  List<Object?> get props => [filter];
}

class LoadEventDetails extends EventsEvent {
  final String eventId;

  const LoadEventDetails(this.eventId);

  @override
  List<Object?> get props => [eventId];
}

class LoadNearbyEvents extends EventsEvent {
  final double latitude;
  final double longitude;
  final double radius;

  const LoadNearbyEvents({
    required this.latitude,
    required this.longitude,
    this.radius = 10,
  });

  @override
  List<Object?> get props => [latitude, longitude, radius];
}

class CreateEvent extends EventsEvent {
  final CreateEventParams params;

  const CreateEvent(this.params);

  @override
  List<Object?> get props => [params];
}

class UpdateLocation extends EventsEvent {
  final LocationEntity? location;

  const UpdateLocation(this.location);

  @override
  List<Object?> get props => [location];
}

// --- Smart Filtering Events ---

class UpdateCategoryFilter extends EventsEvent {
  final String? category;

  const UpdateCategoryFilter(this.category);

  @override
  List<Object?> get props => [category];
}

class UpdateDateFilter extends EventsEvent {
  final DateFilter? dateFilter;

  const UpdateDateFilter(this.dateFilter);

  @override
  List<Object?> get props => [dateFilter];
}

class ToggleTrending extends EventsEvent {}

class UpdateSearchQuery extends EventsEvent {
  final String query;

  const UpdateSearchQuery(this.query);

  @override
  List<Object?> get props => [query];
}

class ClearAllFilters extends EventsEvent {}
