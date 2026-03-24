import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/event.dart';
import '../../domain/repositories/events_repository.dart';
import '../../../location/domain/entities/location_entity.dart';

part 'events_event.dart';
part 'events_state.dart';

const _pollInterval = Duration(seconds: 60);

class EventsBloc extends Bloc<EventsEvent, EventsState> with WidgetsBindingObserver {
  final EventsRepository _eventsRepository;
  LocationEntity? _currentLocation;
  Timer? _searchDebounce;
  Timer? _pollTimer;

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
    on<RefreshEvents>(_onRefreshEvents);

    // Observe app lifecycle to pause/resume polling
    WidgetsBinding.instance.addObserver(this);

    // Start periodic polling for new approved events
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!isClosed) add(RefreshEvents());
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      // Also do an immediate refresh when returning to foreground
      if (!isClosed) add(RefreshEvents());
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _stopPolling();
    }
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
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
        // city is NOT auto-injected to avoid empty pages in small cities
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

  /// Silent refresh — re-fetches page 1 and replaces events only if data changed
  Future<void> _onRefreshEvents(
    RefreshEvents event,
    Emitter<EventsState> emit,
  ) async {
    // Only refresh if we've loaded successfully at least once
    if (state.status != EventsStatus.success &&
        state.status != EventsStatus.loadingMore) return;

    var filter = state.filter.copyWith(page: 1);
    if (_currentLocation != null) {
      filter = filter.copyWith(
        country: filter.country ?? _currentLocation!.countryCode,
        city: filter.city ?? _currentLocation!.city,
      );
    }

    final result = await _eventsRepository.getEvents(filter);

    result.fold(
      (_) {}, // silently ignore errors during poll
      (freshEvents) {
        // Only update UI if the events actually changed
        if (freshEvents.length != state.events.length ||
            (freshEvents.isNotEmpty &&
             state.events.isNotEmpty &&
             freshEvents.first.id != state.events.first.id)) {
          emit(state.copyWith(
            events: freshEvents,
            hasReachedMax: freshEvents.length < state.filter.pageSize,
          ));
        }
      },
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
