import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/network/connectivity_service.dart';
import '../../data/services/geo_service.dart';
import '../../domain/models/map_models.dart';
import 'marker_cluster_manager.dart';

part 'map_state.dart';

class MapStateManager extends Cubit<MapState> {
  MapStateManager(
    this._geoService,
    this._clusterManager,
  ) : super(MapState.initial());

  final GeoService _geoService;
  final MarkerClusterManager _clusterManager;

  static const int _maxCacheEntries = 24;
  static const int _maxVisibleMarkers = 320;
  static const Duration _moveDebounce = Duration(milliseconds: 300);

  final Map<String, NearbyMapResult> _viewportCache = {};
  final Set<String> _inFlightKeys = {};

  Timer? _debounceTimer;
  StreamSubscription<bool>? _connectivitySub;

  LatLng? _northEast;
  LatLng? _southWest;
  String _sessionHash = '';

  Future<void> initialize() async {
    _sessionHash = _geoService.buildSessionHash();
    _trackInteraction('map_open');
    _bindConnectivity();
    _loadFilterOptions();

    emit(state.copyWith(isLocating: true, errorMessage: null));
    final detection = await _geoService.detectUserLocation();
    final center = detection.coordinates ?? state.center;
    emit(state.copyWith(
      center: center,
      isLocating: false,
      locationPermissionDenied:
          detection.permissionDenied && detection.coordinates == null,
    ));

    final bounds = _defaultBounds(center, state.filters.radiusKm);
    await fetchViewport(
      center: center,
      northEast: bounds.$1,
      southWest: bounds.$2,
      zoom: state.zoom,
      forceRefresh: true,
    );
  }

  Future<void> refreshUserLocation() async {
    emit(state.copyWith(isLocating: true));
    final detection = await _geoService.detectUserLocation();
    emit(state.copyWith(
      isLocating: false,
      locationPermissionDenied:
          detection.permissionDenied && detection.coordinates == null,
    ));
    if (detection.coordinates == null) return;

    final bounds =
        _defaultBounds(detection.coordinates!, state.filters.radiusKm);
    await fetchViewport(
      center: detection.coordinates!,
      northEast: bounds.$1,
      southWest: bounds.$2,
      zoom: state.zoom,
      forceRefresh: true,
    );
  }

  void onViewportChanged({
    required LatLng center,
    required LatLng northEast,
    required LatLng southWest,
    required double zoom,
  }) {
    _northEast = northEast;
    _southWest = southWest;
    emit(state.copyWith(center: center, zoom: zoom));

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_moveDebounce, () {
      fetchViewport(
        center: center,
        northEast: northEast,
        southWest: southWest,
        zoom: zoom,
      );
    });
  }

  Future<void> fetchViewport({
    required LatLng center,
    required LatLng northEast,
    required LatLng southWest,
    required double zoom,
    bool forceRefresh = false,
  }) async {
    final cacheKey = _buildCacheKey(
      center: center,
      northEast: northEast,
      southWest: southWest,
      zoom: zoom,
      filters: state.filters,
      page: 1,
      pageSize: 120,
    );

    _northEast = northEast;
    _southWest = southWest;

    if (!ConnectivityService.instance.isOnline) {
      final cached = _viewportCache[cacheKey];
      if (cached != null) {
        _consumeNearbyResult(cached, zoom: zoom, isOffline: true);
      } else {
        emit(state.copyWith(
          status: MapLoadStatus.failure,
          isOffline: true,
          errorMessage: 'Offline and no cached map data for this area.',
        ));
      }
      return;
    }

    if (!forceRefresh && _viewportCache.containsKey(cacheKey)) {
      _consumeNearbyResult(_viewportCache[cacheKey]!,
          zoom: zoom, isOffline: false);
      return;
    }

    if (_inFlightKeys.contains(cacheKey)) return;
    _inFlightKeys.add(cacheKey);
    emit(state.copyWith(
        status: MapLoadStatus.loading, errorMessage: null, isOffline: false));

    try {
      final result = await _geoService.fetchNearby(
        center: center,
        zoom: zoom,
        northEast: northEast,
        southWest: southWest,
        filters: state.filters,
        page: 1,
        pageSize: 120,
      );
      _pushCache(cacheKey, result);
      _consumeNearbyResult(result, zoom: zoom, isOffline: false);

      if (result.hasNextPage && zoom >= 14) {
        unawaited(_loadSecondaryPage(
          center: center,
          northEast: northEast,
          southWest: southWest,
          zoom: zoom,
        ));
      }
      unawaited(_loadContextualPlaces());
    } catch (e) {
      emit(state.copyWith(
        status: MapLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    } finally {
      _inFlightKeys.remove(cacheKey);
    }
  }

  Future<void> updateFilters(MapFilters filters) async {
    emit(state.copyWith(filters: filters, errorMessage: null));
    _trackInteraction('filter_use', metadata: {
      'radius_km': filters.radiusKm,
      'categories': filters.categories.toList(),
      'free_only': filters.freeOnly,
      'almost_full_only': filters.almostFullOnly,
      'date_preset': filters.datePreset.name,
    });

    if (_northEast != null && _southWest != null) {
      await fetchViewport(
        center: state.center,
        northEast: _northEast!,
        southWest: _southWest!,
        zoom: state.zoom,
        forceRefresh: true,
      );
    }
  }

  Future<void> onMarkerTapped(MapEvent event) async {
    emit(state.copyWith(selectedEvent: event));
    _trackInteraction(
      'marker_tap',
      latitude: event.latitude,
      longitude: event.longitude,
      distanceKm: event.distanceKm,
      metadata: {
        'event_id': event.id,
        'category': event.category,
      },
    );
  }

  Future<void> onReservationFromMap(MapEvent event) async {
    _trackInteraction(
      'reservation_from_map',
      latitude: event.latitude,
      longitude: event.longitude,
      distanceKm: event.distanceKm,
      metadata: {'event_id': event.id},
    );
  }

  void clearSelectedEvent() {
    emit(state.copyWith(selectedEvent: null));
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    _connectivitySub?.cancel();
    return super.close();
  }

  Future<void> _loadFilterOptions() async {
    try {
      final options = await _geoService.fetchFilterOptions();
      emit(state.copyWith(filterOptions: options));
    } catch (_) {
      // Keep map usable even if options endpoint fails.
    }
  }

  Future<void> _loadSecondaryPage({
    required LatLng center,
    required LatLng northEast,
    required LatLng southWest,
    required double zoom,
  }) async {
    try {
      final page2 = await _geoService.fetchNearby(
        center: center,
        zoom: zoom,
        northEast: northEast,
        southWest: southWest,
        filters: state.filters,
        page: 2,
        pageSize: 120,
      );
      final merged = <String, MapEvent>{for (final e in state.events) e.id: e};
      for (final event in page2.events) {
        merged[event.id] = event;
        if (merged.length >= _maxVisibleMarkers) break;
      }
      final mergedEvents = merged.values.toList();
      final clusters =
          _clusterManager.buildClusters(events: mergedEvents, zoom: zoom);
      emit(state.copyWith(
        events: mergedEvents,
        clusters: clusters,
        recommendations: _pickRecommendations(mergedEvents),
      ));
    } catch (_) {
      // Lazy page failure should not break the primary result.
    }
  }

  Future<void> _loadContextualPlaces() async {
    if (_northEast == null || _southWest == null) return;
    if (state.filters.contextLayers.isEmpty) {
      emit(state.copyWith(contextPlaces: const []));
      return;
    }

    emit(state.copyWith(contextStatus: MapLoadStatus.loading));
    try {
      final places = await _geoService.fetchContextualPlaces(
        northEast: _northEast!,
        southWest: _southWest!,
        layers: state.filters.contextLayers,
      );
      emit(state.copyWith(
        contextStatus: MapLoadStatus.success,
        contextPlaces: places,
      ));
    } catch (e) {
      emit(state.copyWith(
        contextStatus: MapLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  void _consumeNearbyResult(
    NearbyMapResult result, {
    required double zoom,
    required bool isOffline,
  }) {
    final limited =
        result.events.take(_maxVisibleMarkers).toList(growable: false);
    final clusters = _clusterManager.buildClusters(events: limited, zoom: zoom);
    emit(state.copyWith(
      status: MapLoadStatus.success,
      zoom: zoom,
      isOffline: isOffline,
      events: limited,
      clusters: clusters,
      recommendations: _pickRecommendations(limited),
      errorMessage: null,
    ));
  }

  List<MapEvent> _pickRecommendations(List<MapEvent> events) {
    final sorted = [...events]..sort((a, b) {
        final recommendedOrder =
            (b.recommended ? 1 : 0) - (a.recommended ? 1 : 0);
        if (recommendedOrder != 0) return recommendedOrder;
        final trendingOrder = (b.isTrending ? 1 : 0) - (a.isTrending ? 1 : 0);
        if (trendingOrder != 0) return trendingOrder;
        return b.recommendationScore.compareTo(a.recommendationScore);
      });
    return sorted.take(10).toList(growable: false);
  }

  void _pushCache(String key, NearbyMapResult result) {
    if (_viewportCache.length >= _maxCacheEntries) {
      _viewportCache.remove(_viewportCache.keys.first);
    }
    _viewportCache[key] = result;
  }

  String _buildCacheKey({
    required LatLng center,
    required LatLng northEast,
    required LatLng southWest,
    required double zoom,
    required MapFilters filters,
    required int page,
    required int pageSize,
  }) {
    String normalize(double value) => value.toStringAsFixed(3);
    final categoryKey = filters.categories.toList()..sort();
    final layerKey = filters.contextLayers.map((e) => e.apiValue).toList()
      ..sort();
    return [
      normalize(center.latitude),
      normalize(center.longitude),
      normalize(northEast.latitude),
      normalize(northEast.longitude),
      normalize(southWest.latitude),
      normalize(southWest.longitude),
      zoom.toStringAsFixed(1),
      filters.radiusKm.toStringAsFixed(1),
      filters.datePreset.name,
      filters.resolvedDateFrom?.toIso8601String() ?? '',
      filters.resolvedDateTo?.toIso8601String() ?? '',
      filters.gender ?? '',
      filters.age?.toString() ?? '',
      categoryKey.join('|'),
      filters.freeOnly.toString(),
      filters.almostFullOnly.toString(),
      filters.personalized.toString(),
      filters.sortBy,
      layerKey.join('|'),
      page.toString(),
      pageSize.toString(),
    ].join('::');
  }

  (LatLng, LatLng) _defaultBounds(LatLng center, double radiusKm) {
    final latDelta = radiusKm / 111.0;
    final lngDelta = radiusKm / 111.0;
    final northEast =
        LatLng(center.latitude + latDelta, center.longitude + lngDelta);
    final southWest =
        LatLng(center.latitude - latDelta, center.longitude - lngDelta);
    return (northEast, southWest);
  }

  void _bindConnectivity() {
    _connectivitySub ??=
        ConnectivityService.instance.onConnectivityChanged.listen((online) {
      emit(state.copyWith(isOffline: !online));
      if (online && _northEast != null && _southWest != null) {
        fetchViewport(
          center: state.center,
          northEast: _northEast!,
          southWest: _southWest!,
          zoom: state.zoom,
          forceRefresh: true,
        );
      }
    });
  }

  void _trackInteraction(
    String eventType, {
    double? latitude,
    double? longitude,
    double? distanceKm,
    Map<String, dynamic>? metadata,
  }) {
    unawaited(
      _geoService.trackInteraction(
        eventType: eventType,
        sessionHash: _sessionHash,
        latitude: latitude,
        longitude: longitude,
        distanceKm: distanceKm,
        metadata: metadata,
      ),
    );
  }
}
