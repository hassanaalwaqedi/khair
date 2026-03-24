import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/models/map_models.dart';

class LocationDetectionResult {
  const LocationDetectionResult({
    this.coordinates,
    this.permissionDenied = false,
    this.source = 'none',
  });

  final LatLng? coordinates;
  final bool permissionDenied;
  final String source; // gps | last_known | ip | none
}

class GeoService {
  GeoService(this._apiClient);

  final ApiClient _apiClient;

  Future<LocationDetectionResult> detectUserLocation() async {
    bool permissionDenied = false;

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        // On web this may be unreliable; continue to permission flow anyway.
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permissionDenied = true;
      } else {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 12),
            ),
          );
          return LocationDetectionResult(
            coordinates: LatLng(position.latitude, position.longitude),
            permissionDenied: false,
            source: 'gps',
          );
        } catch (_) {
          // Continue to last-known/IP fallback.
        }
      }
    } catch (_) {
      // Continue to fallbacks.
    }

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        return LocationDetectionResult(
          coordinates: LatLng(last.latitude, last.longitude),
          permissionDenied: permissionDenied,
          source: 'last_known',
        );
      }
    } catch (_) {
      // Continue to IP fallback.
    }

    final ipLocation = await _detectByIP();
    if (ipLocation != null) {
      return LocationDetectionResult(
        coordinates: ipLocation,
        permissionDenied: permissionDenied,
        source: 'ip',
      );
    }

    return LocationDetectionResult(
      coordinates: null,
      permissionDenied: permissionDenied,
      source: 'none',
    );
  }

  Future<NearbyMapResult> fetchNearby({
    required LatLng center,
    required double zoom,
    required LatLng northEast,
    required LatLng southWest,
    required MapFilters filters,
    int page = 1,
    int pageSize = 120,
  }) async {
    final query = <String, dynamic>{
      'lat': center.latitude.toStringAsFixed(6),
      'lng': center.longitude.toStringAsFixed(6),
      'radius_km': filters.radiusKm.toStringAsFixed(2),
      'min_lat': southWest.latitude.toStringAsFixed(6),
      'min_lng': southWest.longitude.toStringAsFixed(6),
      'max_lat': northEast.latitude.toStringAsFixed(6),
      'max_lng': northEast.longitude.toStringAsFixed(6),
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'zoom': zoom.toStringAsFixed(2),
    };

    if (filters.search.isNotEmpty) {
      query['search'] = filters.search;
    }

    for (final category in filters.categories) {
      query.putIfAbsent('categories[]', () => <String>[]);
      (query['categories[]'] as List<String>).add(category);
    }

    final response =
        await _apiClient.get('/map/nearby', queryParameters: query);
    final payload = response.data['data'] as Map<String, dynamic>;
    return NearbyMapResult.fromJson(payload);
  }

  Future<void> trackInteraction({
    required String eventType,
    required String sessionHash,
    double? latitude,
    double? longitude,
    double? distanceKm,
    Map<String, dynamic>? metadata,
  }) async {
    final body = <String, dynamic>{
      'event_type': eventType,
      'session_hash': sessionHash,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (distanceKm != null) 'distance_km': distanceKm,
      'metadata': metadata ?? const <String, dynamic>{},
    };
    await _apiClient.post('/map/geo-interactions', data: body);
  }

  String buildSessionHash() {
    final seed = DateTime.now().toIso8601String();
    return base64Url.encode(utf8.encode(seed)).replaceAll('=', '');
  }

  Future<LatLng?> _detectByIP() async {
    try {
      final response = await _apiClient.get('/location/resolve');
      final data = response.data['data'] as Map<String, dynamic>?;
      if (data == null) return null;
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }
}
