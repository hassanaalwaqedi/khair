import '../../../../core/network/api_client.dart';
import '../../domain/entities/sheikh_profile.dart';

/// Data source for fetching sheikh profiles from the API.
class SheikhRemoteDataSource {
  final ApiClient _apiClient;

  SheikhRemoteDataSource(this._apiClient);

  /// Fetch all public sheikh profiles.
  Future<List<SheikhProfile>> getSheikhs() async {
    final response = await _apiClient.get('/sheikhs');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => SheikhProfile.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
