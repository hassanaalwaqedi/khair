import '../../domain/entities/location_entity.dart';

class LocationModel extends LocationEntity {
  const LocationModel({
    required super.country,
    required super.countryCode,
    required super.city,
    required super.timezone,
    super.latitude,
    super.longitude,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      country: json['country'] as String? ?? '',
      countryCode: json['country_code'] as String? ?? '',
      city: json['city'] as String? ?? '',
      timezone: json['timezone'] as String? ?? 'UTC',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'country': country,
      'country_code': countryCode,
      'city': city,
      'timezone': timezone,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Create from SharedPreferences cache
  factory LocationModel.fromCache(Map<String, String> cache) {
    return LocationModel(
      country: cache['location_country'] ?? '',
      countryCode: cache['location_country_code'] ?? '',
      city: cache['location_city'] ?? '',
      timezone: cache['location_timezone'] ?? 'UTC',
      latitude: cache['location_lat'] != null
          ? double.tryParse(cache['location_lat']!)
          : null,
      longitude: cache['location_lng'] != null
          ? double.tryParse(cache['location_lng']!)
          : null,
    );
  }
}
