import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/location_entity.dart';
import '../repository/location_repository.dart';

class ResolveLocationUseCase {
  final LocationRepository _repository;

  ResolveLocationUseCase(this._repository);

  /// Resolves location: loads cache first, then refreshes from API
  Future<Either<Failure, LocationEntity>> call({
    double? latitude,
    double? longitude,
  }) async {
    return _repository.resolveLocation(
      latitude: latitude,
      longitude: longitude,
    );
  }

  Future<LocationEntity?> getCachedLocation() {
    return _repository.getCachedLocation();
  }

  Future<void> cacheLocation(LocationEntity location) {
    return _repository.cacheLocation(location);
  }
}
