import '../../../../core/network/api_client.dart';
import '../models/location_model.dart';

abstract class LocationRemoteDataSource {
  Future<LocationModel> resolveLocation({double? lat, double? lng});
}

class LocationRemoteDataSourceImpl implements LocationRemoteDataSource {
  final ApiClient _apiClient;

  LocationRemoteDataSourceImpl(this._apiClient);

  @override
  Future<LocationModel> resolveLocation({double? lat, double? lng}) async {
    final queryParams = <String, dynamic>{};
    if (lat != null && lng != null) {
      queryParams['lat'] = lat.toString();
      queryParams['lng'] = lng.toString();
    }

    final response = await _apiClient.get(
      '/location/resolve',
      queryParameters: queryParams,
    );

    return LocationModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }
}
