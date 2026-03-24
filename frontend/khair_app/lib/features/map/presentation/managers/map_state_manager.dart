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

  static const int _maxVisibleMarkers = 200;
  static const int _maxCacheEntries = 24;

  final Map<String, NearbyMapResult> _viewportCache = {};
  final Set<String> _inFlightKeys = {};
  StreamSubscription<bool>? _connectivitySub;
  String _sessionHash = '';

  LatLng? _northEast;
  LatLng? _southWest;

  // ─── Lifecycle ────────────────────────────────

  Future<void> initialize() async {
    _sessionHash = _geoService.buildSessionHash();
    _trackInteraction('map_open');
    _bindConnectivity();

    emit(state.copyWith(isLocating: true, errorMessage: null));
    final detection = await _geoService.detectUserLocation();
    final center = detection.coordinates ?? state.center;
    emit(state.copyWith(
      center: center,
      isLocating: false,
      locationPermissionDenied:
          detection.permissionDenied && detection.coordinates == null,
    ));

    // Auto-fetch on initial load only
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

  // ─── Viewport tracking (NO auto-fetch) ────────

  void onViewportChanged({
    required LatLng center,
    required LatLng northEast,
    required LatLng southWest,
    required double zoom,
  }) {
    _northEast = northEast;
    _southWest = southWest;
    // Only track position + show button, do NOT auto-fetch
    emit(state.copyWith(
      center: center,
      zoom: zoom,
      showSearchAreaButton: true,
    ));
  }

  // ─── "Search this area" ───────────────────────

  Future<void> searchThisArea() async {
    emit(state.copyWith(showSearchAreaButton: false));
    if (_northEast == null || _southWest == null) return;
    await fetchViewport(
      center: state.center,
      northEast: _northEast!,
      southWest: _southWest!,
      zoom: state.zoom,
      forceRefresh: true,
    );
  }

  // ─── Data fetching ────────────────────────────

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
        status: MapLoadStatus.loading,
        errorMessage: null,
        isOffline: false));

    try {
      final result = await _geoService.fetchNearby(
        center: center,
        zoom: zoom,
        northEast: northEast,
        southWest: southWest,
        filters: state.filters,
        pageSize: 120,
      );
      _pushCache(cacheKey, result);
      _consumeNearbyResult(result, zoom: zoom, isOffline: false);
    } catch (e) {
      emit(state.copyWith(
        status: MapLoadStatus.failure,
        errorMessage: e.toString(),
      ));
    } finally {
      _inFlightKeys.remove(cacheKey);
    }
  }

  // ─── Filters ──────────────────────────────────

  Future<void> updateFilters(MapFilters filters) async {
    emit(state.copyWith(filters: filters, errorMessage: null));
    _trackInteraction('filter_use', metadata: {
      'radius_km': filters.radiusKm,
      'categories': filters.categories.toList(),
      'event_type': filters.eventType,
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

  // ─── Marker interaction ───────────────────────

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
    _connectivitySub?.cancel();
    return super.close();
  }

  // ─── Internal ─────────────────────────────────

  void _consumeNearbyResult(
    NearbyMapResult result, {
    required double zoom,
    required bool isOffline,
  }) {
    final limited =
        result.events.take(_maxVisibleMarkers).toList(growable: false);
    final clusters =
        _clusterManager.buildClusters(events: limited, zoom: zoom);
    emit(state.copyWith(
      status: MapLoadStatus.success,
      zoom: zoom,
      isOffline: isOffline,
      events: limited,
      clusters: clusters,
      showSearchAreaButton: false,
      errorMessage: null,
    ));
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
  }) {
    String normalize(double value) => value.toStringAsFixed(3);
    final categoryKey = filters.categories.toList()..sort();
    return [
      normalize(center.latitude),
      normalize(center.longitude),
      normalize(northEast.latitude),
      normalize(northEast.longitude),
      normalize(southWest.latitude),
      normalize(southWest.longitude),
      zoom.toStringAsFixed(1),
      filters.radiusKm.toStringAsFixed(1),
      filters.eventType,
      categoryKey.join('|'),
      filters.search,
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
