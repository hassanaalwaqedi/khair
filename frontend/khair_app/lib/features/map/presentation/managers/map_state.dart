part of 'map_state_manager.dart';

enum MapLoadStatus { initial, loading, success, failure }

class MapState extends Equatable {
  const MapState({
    required this.status,
    required this.center,
    required this.zoom,
    required this.events,
    required this.clusters,
    required this.filters,
    required this.categories,
    required this.isLocating,
    required this.locationPermissionDenied,
    required this.isOffline,
    required this.showSearchAreaButton,
    required this.places,
    required this.isSearchingPlaces,
    this.selectedEvent,
    this.errorMessage,
  });

  factory MapState.initial() {
    return const MapState(
      status: MapLoadStatus.initial,
      center: LatLng(40.7128, -74.0060),
      zoom: 12,
      events: [],
      clusters: [],
      filters: MapFilters(),
      categories: [],
      isLocating: false,
      locationPermissionDenied: false,
      isOffline: false,
      showSearchAreaButton: false,
      places: [],
      isSearchingPlaces: false,
    );
  }

  final MapLoadStatus status;
  final LatLng center;
  final double zoom;
  final List<MapEvent> events;
  final List<MapClusterNode> clusters;
  final MapFilters filters;
  final List<MapCategory> categories;
  final bool isLocating;
  final bool locationPermissionDenied;
  final bool isOffline;
  final bool showSearchAreaButton;
  final List<NominatimPlace> places;
  final bool isSearchingPlaces;
  final MapEvent? selectedEvent;
  final String? errorMessage;

  MapState copyWith({
    MapLoadStatus? status,
    LatLng? center,
    double? zoom,
    List<MapEvent>? events,
    List<MapClusterNode>? clusters,
    MapFilters? filters,
    List<MapCategory>? categories,
    bool? isLocating,
    bool? locationPermissionDenied,
    bool? isOffline,
    bool? showSearchAreaButton,
    List<NominatimPlace>? places,
    bool? isSearchingPlaces,
    MapEvent? selectedEvent,
    String? errorMessage,
    bool clearSelectedEvent = false,
    bool clearError = false,
  }) {
    return MapState(
      status: status ?? this.status,
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      events: events ?? this.events,
      clusters: clusters ?? this.clusters,
      filters: filters ?? this.filters,
      categories: categories ?? this.categories,
      isLocating: isLocating ?? this.isLocating,
      locationPermissionDenied:
          locationPermissionDenied ?? this.locationPermissionDenied,
      isOffline: isOffline ?? this.isOffline,
      showSearchAreaButton: showSearchAreaButton ?? this.showSearchAreaButton,
      places: places ?? this.places,
      isSearchingPlaces: isSearchingPlaces ?? this.isSearchingPlaces,
      selectedEvent:
          clearSelectedEvent ? null : (selectedEvent ?? this.selectedEvent),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        center,
        zoom,
        events,
        clusters,
        filters,
        categories,
        isLocating,
        locationPermissionDenied,
        isOffline,
        showSearchAreaButton,
        places,
        isSearchingPlaces,
        selectedEvent,
        errorMessage,
      ];
}
