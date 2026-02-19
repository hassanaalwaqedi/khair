import 'package:dartz/dartz.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/location_entity.dart';
import '../../domain/repository/location_repository.dart';
import '../datasource/location_remote_datasource.dart';
import '../models/location_model.dart';

class LocationRepositoryImpl implements LocationRepository {
  final LocationRemoteDataSource _remoteDataSource;

  LocationRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, LocationEntity>> resolveLocation({
    double? latitude,
    double? longitude,
  }) async {
    try {
      final result = await _remoteDataSource.resolveLocation(
        lat: latitude,
        lng: longitude,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<LocationEntity?> getCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final country = prefs.getString('location_country');
      final countryCode = prefs.getString('location_country_code');
      final city = prefs.getString('location_city');
      final timezone = prefs.getString('location_timezone');

      if (country == null || countryCode == null || city == null) {
        return null;
      }

      return LocationModel.fromCache({
        'location_country': country,
        'location_country_code': countryCode,
        'location_city': city,
        'location_timezone': timezone ?? 'UTC',
        if (prefs.getString('location_lat') != null)
          'location_lat': prefs.getString('location_lat')!,
        if (prefs.getString('location_lng') != null)
          'location_lng': prefs.getString('location_lng')!,
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cacheLocation(LocationEntity location) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('location_country', location.country);
      await prefs.setString('location_country_code', location.countryCode);
      await prefs.setString('location_city', location.city);
      await prefs.setString('location_timezone', location.timezone);
      if (location.latitude != null) {
        await prefs.setString('location_lat', location.latitude.toString());
      }
      if (location.longitude != null) {
        await prefs.setString('location_lng', location.longitude.toString());
      }
    } catch (_) {
      // Silently fail caching
    }
  }
}
