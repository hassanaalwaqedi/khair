import 'package:dio/dio.dart';

/// Service for OpenStreetMap Nominatim geocoding API.
/// No API key required — fully free.
class NominatimService {
  static final _dio = Dio(BaseOptions(
    baseUrl: 'https://nominatim.openstreetmap.org',
    headers: {'User-Agent': 'KhairApp/1.0'},
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Forward geocoding — search places by name.
  static Future<List<NominatimPlace>> search(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get('/search', queryParameters: {
        'q': query,
        'format': 'json',
        'addressdetails': 1,
        'limit': 8,
      });

      final data = response.data as List;
      return data.map((e) => NominatimPlace.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Reverse geocoding — get address from coordinates.
  static Future<NominatimPlace?> reverseGeocode(
      double lat, double lng) async {
    try {
      final response = await _dio.get('/reverse', queryParameters: {
        'lat': lat,
        'lon': lng,
        'format': 'json',
        'addressdetails': 1,
      });

      return NominatimPlace.fromJson(response.data);
    } catch (_) {
      return null;
    }
  }
}

/// Represents a place result from Nominatim.
class NominatimPlace {
  final double lat;
  final double lng;
  final String displayName;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? road;
  final String? state;

  const NominatimPlace({
    required this.lat,
    required this.lng,
    required this.displayName,
    this.city,
    this.country,
    this.countryCode,
    this.road,
    this.state,
  });

  factory NominatimPlace.fromJson(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};
    return NominatimPlace(
      lat: double.tryParse(json['lat']?.toString() ?? '') ?? 0,
      lng: double.tryParse(json['lon']?.toString() ?? '') ?? 0,
      displayName: json['display_name'] ?? '',
      city: address['city'] ??
          address['town'] ??
          address['village'] ??
          address['county'],
      country: address['country'],
      countryCode: (address['country_code'] as String?)?.toUpperCase(),
      road: address['road'] ?? address['pedestrian'] ?? address['suburb'],
      state: address['state'],
    );
  }

  /// Short formatted address.
  String get shortAddress {
    final parts = <String>[];
    if (road != null) parts.add(road!);
    if (city != null) parts.add(city!);
    if (country != null) parts.add(country!);
    return parts.isNotEmpty ? parts.join(', ') : displayName;
  }
}
