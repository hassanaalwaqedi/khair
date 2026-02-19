import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/location_entity.dart';

abstract class LocationRepository {
  /// Resolve location from coordinates or IP fallback
  Future<Either<Failure, LocationEntity>> resolveLocation({
    double? latitude,
    double? longitude,
  });

  /// Get cached location from SharedPreferences
  Future<LocationEntity?> getCachedLocation();

  /// Save location to SharedPreferences cache
  Future<void> cacheLocation(LocationEntity location);
}
