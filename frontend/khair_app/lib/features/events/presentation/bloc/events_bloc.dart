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

class EventsBloc extends Bloc<EventsEvent, EventsState>
    with WidgetsBindingObserver {
  final EventsRepository _eventsRepository;
  LocationEntity? _currentLocation;
  Timer? _searchDebounce;
  Timer? _pollTimer;
  int _queryGeneration = 0;

  EventsBloc(this._eventsRepository) : super(const EventsState()) {
    on<LoadEvents>(_onLoadEvents);
    on<LoadMoreEvents>(_onLoadMoreEvents);
    on<UpdateFilter>(_onUpdateFilter);
    on<LoadEventDetails>(_onLoadEventDetails);
    on<LoadNearbyEvents>(_onLoadNearbyEvents);
    on<CreateEvent>(_onCreateEvent);
    on<UpdateLocation>(_onUpdateLocation);
    on<UpdateBaseCity>(_onUpdateBaseCity);
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
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
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
    add(UpdateFilter(state.filter));
  }

  void _onUpdateBaseCity(
    UpdateBaseCity event,
    Emitter<EventsState> emit,
  ) {
    if (_currentLocation != null) {
      _currentLocation = LocationEntity(
        country: _currentLocation!.country,
        countryCode: _currentLocation!.countryCode,
        city: event.city,
        timezone: _currentLocation!.timezone,
        latitude: _currentLocation!.latitude,
        longitude: _currentLocation!.longitude,
      );
    } else {
      _currentLocation = LocationEntity(
        country: '',
        countryCode: '',
        city: event.city,
        timezone: '',
      );
    }
    // Clear the temporary filter city so that base city takes effect
    add(UpdateFilter(state.filter.copyWith(
      city: null,
      clearCity: true,
      country: null,
      clearCountry: true,
    )));
  }

  void _onUpdateCategoryFilter(
    UpdateCategoryFilter event,
    Emitter<EventsState> emit,
  ) {
    add(UpdateFilter(state.filter.copyWith(
      category: event.category,
      clearCategory: event.category == null,
    )));
  }

  void _onUpdateDateFilter(
    UpdateDateFilter event,
    Emitter<EventsState> emit,
  ) {
    add(UpdateFilter(state.filter.copyWith(
      dateFilter: event.dateFilter,
      clearDateFilter: event.dateFilter == null,
    )));
  }

  void _onToggleTrending(
    ToggleTrending event,
    Emitter<EventsState> emit,
  ) {
    add(UpdateFilter(state.filter.copyWith(trending: !state.filter.trending)));
  }

  void _onUpdateSearchQuery(
    UpdateSearchQuery event,
    Emitter<EventsState> emit,
  ) {
    _searchDebounce?.cancel();
    final query = event.query.trim();
    if (query.isEmpty) {
      add(UpdateFilter(state.filter.copyWith(clearSearchQuery: true)));
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!isClosed) {
        add(UpdateFilter(state.filter.copyWith(searchQuery: query)));
      }
    });
  }

  void _onClearAllFilters(
    ClearAllFilters event,
    Emitter<EventsState> emit,
  ) {
    add(UpdateFilter(state.filter.clearFilters()));
  }

  Future<void> _onLoadEvents(
    LoadEvents event,
    Emitter<EventsState> emit,
  ) async {
    final generation = event.generation ?? _queryGeneration;
    final requestedFilter = event.filter ?? state.filter;
    emit(state.copyWith(status: EventsStatus.loading));

    // Inject location into filter if available and not already set
    var filter = requestedFilter;
    if (_currentLocation != null) {
      filter = filter.copyWith(
        country: filter.country ?? _currentLocation!.countryCode,
        city: filter.city ?? _currentLocation!.city,
        timezone: filter.timezone ?? _currentLocation!.timezone,
      );
    }

    final result = await _eventsRepository.getEvents(filter);

    if (generation != _queryGeneration || isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: EventsStatus.failure,
        errorMessage: failure.message,
      )),
      (events) => emit(state.copyWith(
        status: EventsStatus.success,
        events: events,
        filter: filter,
        hasReachedMax: events.length < filter.pageSize,
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
        state.status != EventsStatus.loadingMore) {
      return;
    }

    final refreshGeneration = _queryGeneration;
    var filter = state.filter.copyWith(page: 1);
    if (_currentLocation != null) {
      filter = filter.copyWith(
        country: filter.country ?? _currentLocation!.countryCode,
        city: filter.city ?? _currentLocation!.city,
      );
    }

    final result = await _eventsRepository.getEvents(filter);

    if (refreshGeneration != _queryGeneration || isClosed) return;

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

    final loadGeneration = _queryGeneration;
    final baseFilter = state.filter;
    var newFilter = baseFilter.copyWith(page: baseFilter.page + 1);

    // Inject location into pagination too
    if (_currentLocation != null) {
      newFilter = newFilter.copyWith(
        country: newFilter.country ?? _currentLocation!.countryCode,
        city: newFilter.city ?? _currentLocation!.city,
      );
    }

    final result = await _eventsRepository.getEvents(newFilter);

    if (loadGeneration != _queryGeneration || isClosed) return;

    result.fold(
      (failure) => emit(state.copyWith(
        status: EventsStatus.failure,
        errorMessage: failure.message,
      )),
      (events) {
        final knownIds = state.events.map((item) => item.id).toSet();
        final uniqueEvents = events.where((item) => knownIds.add(item.id)).toList();
        emit(state.copyWith(
        status: EventsStatus.success,
        events: [...state.events, ...uniqueEvents],
        filter: newFilter,
        hasReachedMax: events.length < newFilter.pageSize,
        ));
      },
    );
  }

  Future<void> _onUpdateFilter(
    UpdateFilter event,
    Emitter<EventsState> emit,
  ) async {
    final newFilter = event.filter.copyWith(page: 1);
    final generation = ++_queryGeneration;
    emit(state.copyWith(
      status: EventsStatus.loading,
      filter: newFilter,
      events: [],
      hasReachedMax: false,
    ));
    add(LoadEvents(filter: newFilter, generation: generation));
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
