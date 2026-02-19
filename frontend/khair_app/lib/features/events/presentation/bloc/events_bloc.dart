import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/event.dart';
import '../../domain/repositories/events_repository.dart';
import '../../../location/domain/entities/location_entity.dart';

part 'events_event.dart';
part 'events_state.dart';

class EventsBloc extends Bloc<EventsEvent, EventsState> {
  final EventsRepository _eventsRepository;
  LocationEntity? _currentLocation;
  Timer? _searchDebounce;

  EventsBloc(this._eventsRepository) : super(const EventsState()) {
    on<LoadEvents>(_onLoadEvents);
    on<LoadMoreEvents>(_onLoadMoreEvents);
    on<UpdateFilter>(_onUpdateFilter);
    on<LoadEventDetails>(_onLoadEventDetails);
    on<LoadNearbyEvents>(_onLoadNearbyEvents);
    on<CreateEvent>(_onCreateEvent);
    on<UpdateLocation>(_onUpdateLocation);
    on<UpdateCategoryFilter>(_onUpdateCategoryFilter);
    on<UpdateDateFilter>(_onUpdateDateFilter);
    on<ToggleTrending>(_onToggleTrending);
    on<UpdateSearchQuery>(_onUpdateSearchQuery);
    on<ClearAllFilters>(_onClearAllFilters);
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }

  void _onUpdateLocation(
    UpdateLocation event,
    Emitter<EventsState> emit,
  ) {
    _currentLocation = event.location;
    // Reload events with location filter
    add(LoadEvents());
  }

  void _onUpdateCategoryFilter(
    UpdateCategoryFilter event,
    Emitter<EventsState> emit,
  ) {
    final newFilter = state.filter.copyWith(
      eventType: event.category,
      page: 1,
    );
    emit(state.copyWith(
      filter: newFilter,
      events: [],
      hasReachedMax: false,
    ));
    add(LoadEvents());
  }

  void _onUpdateDateFilter(
    UpdateDateFilter event,
    Emitter<EventsState> emit,
  ) {
    // Create a fresh filter with the new date filter
    final newFilter = EventFilter(
      country: state.filter.country,
      city: state.filter.city,
      eventType: state.filter.eventType,
      language: state.filter.language,
      searchQuery: state.filter.searchQuery,
      dateFilter: event.dateFilter,
      trending: state.filter.trending,
      page: 1,
      pageSize: state.filter.pageSize,
    );
    emit(state.copyWith(
      filter: newFilter,
      events: [],
      hasReachedMax: false,
    ));
    add(LoadEvents());
  }

  void _onToggleTrending(
    ToggleTrending event,
    Emitter<EventsState> emit,
  ) {
    final newFilter = state.filter.copyWith(
      trending: !state.filter.trending,
      page: 1,
    );
    emit(state.copyWith(
      filter: newFilter,
      events: [],
      hasReachedMax: false,
    ));
    add(LoadEvents());
  }

  void _onUpdateSearchQuery(
    UpdateSearchQuery event,
    Emitter<EventsState> emit,
  ) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      add(UpdateFilter(state.filter.copyWith(
        searchQuery: event.query.isEmpty ? null : event.query,
        page: 1,
      )));
    });
  }

  void _onClearAllFilters(
    ClearAllFilters event,
    Emitter<EventsState> emit,
  ) {
    final newFilter = state.filter.clearFilters();
    emit(state.copyWith(
      filter: newFilter,
      events: [],
      hasReachedMax: false,
    ));
    add(LoadEvents());
  }

  Future<void> _onLoadEvents(
    LoadEvents event,
    Emitter<EventsState> emit,
  ) async {
    emit(state.copyWith(status: EventsStatus.loading));

    // Inject location into filter if available and not already set
    var filter = state.filter;
    if (_currentLocation != null) {
      filter = filter.copyWith(
        country: filter.country ?? _currentLocation!.countryCode,
        city: filter.city ?? _currentLocation!.city,
      );
    }

    final result = await _eventsRepository.getEvents(filter);

    result.fold(
      (failure) => emit(state.copyWith(
        status: EventsStatus.failure,
        errorMessage: failure.message,
      )),
      (events) => emit(state.copyWith(
        status: EventsStatus.success,
        events: events,
        hasReachedMax: events.length < state.filter.pageSize,
      )),
    );
  }

  Future<void> _onLoadMoreEvents(
    LoadMoreEvents event,
    Emitter<EventsState> emit,
  ) async {
    if (state.hasReachedMax) return;

    emit(state.copyWith(status: EventsStatus.loadingMore));

    var newFilter = state.filter.copyWith(page: state.filter.page + 1);
    
    // Inject location into pagination too
    if (_currentLocation != null) {
      newFilter = newFilter.copyWith(
        country: newFilter.country ?? _currentLocation!.countryCode,
        city: newFilter.city ?? _currentLocation!.city,
      );
    }

    final result = await _eventsRepository.getEvents(newFilter);

    result.fold(
      (failure) => emit(state.copyWith(
        status: EventsStatus.failure,
        errorMessage: failure.message,
      )),
      (events) => emit(state.copyWith(
        status: EventsStatus.success,
        events: [...state.events, ...events],
        filter: newFilter,
        hasReachedMax: events.length < state.filter.pageSize,
      )),
    );
  }

  Future<void> _onUpdateFilter(
    UpdateFilter event,
    Emitter<EventsState> emit,
  ) async {
    final newFilter = event.filter.copyWith(page: 1);
    emit(state.copyWith(
      filter: newFilter,
      events: [],
      hasReachedMax: false,
    ));
    add(LoadEvents());
  }

  Future<void> _onLoadEventDetails(
    LoadEventDetails event,
    Emitter<EventsState> emit,
  ) async {
    emit(state.copyWith(detailsStatus: EventsStatus.loading));

    final result = await _eventsRepository.getEventById(event.eventId);

    result.fold(
      (failure) => emit(state.copyWith(
        detailsStatus: EventsStatus.failure,
        errorMessage: failure.message,
      )),
      (eventDetails) => emit(state.copyWith(
        detailsStatus: EventsStatus.success,
        selectedEvent: eventDetails,
      )),
    );
  }

  Future<void> _onLoadNearbyEvents(
    LoadNearbyEvents event,
    Emitter<EventsState> emit,
  ) async {
    emit(state.copyWith(nearbyStatus: EventsStatus.loading));

    final result = await _eventsRepository.getNearbyEvents(
      latitude: event.latitude,
      longitude: event.longitude,
      radius: event.radius,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        nearbyStatus: EventsStatus.failure,
        errorMessage: failure.message,
      )),
      (events) => emit(state.copyWith(
        nearbyStatus: EventsStatus.success,
        nearbyEvents: events,
      )),
    );
  }

  Future<void> _onCreateEvent(
    CreateEvent event,
    Emitter<EventsState> emit,
  ) async {
    emit(state.copyWith(createStatus: EventsStatus.loading));

    final result = await _eventsRepository.createEvent(event.params);

    result.fold(
      (failure) => emit(state.copyWith(
        createStatus: EventsStatus.failure,
        errorMessage: failure.message,
      )),
      (createdEvent) => emit(state.copyWith(
        createStatus: EventsStatus.success,
        selectedEvent: createdEvent,
      )),
    );
  }
}
