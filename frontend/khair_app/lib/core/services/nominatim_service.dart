import 'package:dio/dio.dart';

import '../config/api_config.dart';

/// Service for OpenStreetMap Nominatim geocoding API.
/// No API key required — fully free.
class NominatimService {
  static final _dio = Dio(BaseOptions(
    baseUrl: ApiConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Forward geocoding — search places by name.
  static Future<List<NominatimPlace>> search(
    String query, {
    String? city,
    String? country,
    double? latitude,
    double? longitude,
    String? language,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      final response = await _dio.get('/location/search', queryParameters: {
        'q': query,
        if (city?.isNotEmpty == true) 'city': city,
        if (country?.isNotEmpty == true) 'country': country,
        if (latitude != null && longitude != null) ...{
          'lat': latitude,
          'lng': longitude,
        },
        if (language?.isNotEmpty == true) 'language': language,
      });

      final body = response.data as Map<String, dynamic>;
      final data = body['data'] as List? ?? const [];
      return data.map((e) => NominatimPlace.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Reverse geocoding — get address from coordinates.
  static Future<NominatimPlace?> reverseGeocode(double lat, double lng,
      {String? language}) async {
    try {
      final response = await _dio.get('/location/reverse', queryParameters: {
        'lat': lat,
        'lng': lng,
        if (language?.isNotEmpty == true) 'language': language,
      });

      final body = response.data as Map<String, dynamic>;
      return NominatimPlace.fromJson(body['data'] as Map<String, dynamic>);
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
  final String? name;
  final String? category;
  final String? district;
  final String? postalCode;
  final double? distanceKm;

  const NominatimPlace({
    required this.lat,
    required this.lng,
    required this.displayName,
    this.city,
    this.country,
    this.countryCode,
    this.road,
    this.state,
    this.name,
    this.category,
    this.district,
    this.postalCode,
    this.distanceKm,
  });

  factory NominatimPlace.fromJson(Map<String, dynamic> json) {
    final address = json['address'] is Map
        ? Map<String, dynamic>.from(json['address'] as Map)
        : <String, dynamic>{};
    return NominatimPlace(
      lat: double.tryParse(
              (json['latitude'] ?? json['lat'])?.toString() ?? '') ??
          0,
      lng: double.tryParse(
              (json['longitude'] ?? json['lon'])?.toString() ?? '') ??
          0,
      displayName: json['display_name'] ?? json['address'] ?? '',
      name: json['name'],
      category: json['category'],
      district: json['district'],
      postalCode: json['postal_code'],
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      city: json['city'] ??
          address['city'] ??
          address['town'] ??
          address['village'] ??
          address['county'],
      country: json['country'] ?? address['country'],
      countryCode:
          ((json['country_code'] ?? address['country_code']) as String?)
              ?.toUpperCase(),
      road: json['street'] ??
          address['road'] ??
          address['pedestrian'] ??
          address['suburb'],
      state: json['state'] ?? address['state'],
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
