part of 'map_state_manager.dart';

enum MapLoadStatus { initial, loading, success, failure }

class MapState extends Equatable {
  const MapState({
    required this.status,
    required this.contextStatus,
    required this.center,
    required this.zoom,
    required this.events,
    required this.clusters,
    required this.contextPlaces,
    required this.recommendations,
    required this.filters,
    required this.filterOptions,
    required this.isLocating,
    required this.locationPermissionDenied,
    required this.isOffline,
    this.selectedEvent,
    this.errorMessage,
  });

  factory MapState.initial() {
    return const MapState(
      status: MapLoadStatus.initial,
      contextStatus: MapLoadStatus.initial,
      center: LatLng(40.7128, -74.0060),
      zoom: 12,
      events: [],
      clusters: [],
      contextPlaces: [],
      recommendations: [],
      filters: MapFilters(),
      filterOptions: MapFilterOptions(
        categories: [],
        genderRestrictions: [],
        radiusOptionsKm: [5, 10, 25, 50],
      ),
      isLocating: false,
      locationPermissionDenied: false,
      isOffline: false,
    );
  }

  final MapLoadStatus status;
  final MapLoadStatus contextStatus;
  final LatLng center;
  final double zoom;
  final List<MapEvent> events;
  final List<MapClusterNode> clusters;
  final List<MapContextPlace> contextPlaces;
  final List<MapEvent> recommendations;
  final MapFilters filters;
  final MapFilterOptions filterOptions;
  final bool isLocating;
  final bool locationPermissionDenied;
  final bool isOffline;
  final MapEvent? selectedEvent;
  final String? errorMessage;

  MapState copyWith({
    MapLoadStatus? status,
    MapLoadStatus? contextStatus,
    LatLng? center,
    double? zoom,
    List<MapEvent>? events,
    List<MapClusterNode>? clusters,
    List<MapContextPlace>? contextPlaces,
    List<MapEvent>? recommendations,
    MapFilters? filters,
    MapFilterOptions? filterOptions,
    bool? isLocating,
    bool? locationPermissionDenied,
    bool? isOffline,
    MapEvent? selectedEvent,
    String? errorMessage,
    bool clearSelectedEvent = false,
    bool clearError = false,
  }) {
    return MapState(
      status: status ?? this.status,
      contextStatus: contextStatus ?? this.contextStatus,
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      events: events ?? this.events,
      clusters: clusters ?? this.clusters,
      contextPlaces: contextPlaces ?? this.contextPlaces,
      recommendations: recommendations ?? this.recommendations,
      filters: filters ?? this.filters,
      filterOptions: filterOptions ?? this.filterOptions,
      isLocating: isLocating ?? this.isLocating,
      locationPermissionDenied:
          locationPermissionDenied ?? this.locationPermissionDenied,
      isOffline: isOffline ?? this.isOffline,
      selectedEvent:
          clearSelectedEvent ? null : (selectedEvent ?? this.selectedEvent),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        contextStatus,
        center,
        zoom,
        events,
        clusters,
        contextPlaces,
        recommendations,
        filters,
        filterOptions,
        isLocating,
        locationPermissionDenied,
        isOffline,
        selectedEvent,
        errorMessage,
      ];
}
