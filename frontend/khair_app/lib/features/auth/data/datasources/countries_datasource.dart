import '../../../../core/network/api_client.dart';
import '../models/country_model.dart';

/// Data source for countries API
class CountriesDataSource {
  final ApiClient _apiClient;

  CountriesDataSource(this._apiClient);

  /// Fetch all active countries
  Future<List<Country>> getAll() async {
    final response = await _apiClient.get('/countries');
    final data = response.data['data'] as List<dynamic>;
    return data.map((json) => Country.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Search countries by name or ISO code
  Future<List<Country>> search(String query) async {
    final response = await _apiClient.get('/countries/search', queryParameters: {'q': query});
    final data = response.data['data'] as List<dynamic>;
    return data.map((json) => Country.fromJson(json as Map<String, dynamic>)).toList();
  }
}
