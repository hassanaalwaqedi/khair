import 'package:equatable/equatable.dart';

class LocationEntity extends Equatable {
  final String country;
  final String countryCode;
  final String city;
  final String timezone;
  final double? latitude;
  final double? longitude;

  const LocationEntity({
    required this.country,
    required this.countryCode,
    required this.city,
    required this.timezone,
    this.latitude,
    this.longitude,
  });

  @override
  List<Object?> get props => [country, countryCode, city, timezone, latitude, longitude];
}
