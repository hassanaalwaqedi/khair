import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/spiritual_quote.dart';
import '../models/spiritual_quote_model.dart';

abstract class SpiritualQuotesRemoteDataSource {
  Future<SpiritualQuoteModel?> getRandomQuote({
    required QuoteLocation location,
  });
}

class SpiritualQuotesRemoteDataSourceImpl
    implements SpiritualQuotesRemoteDataSource {
  final ApiClient _apiClient;

  SpiritualQuotesRemoteDataSourceImpl(this._apiClient);

  @override
  Future<SpiritualQuoteModel?> getRandomQuote({
    required QuoteLocation location,
  }) async {
    try {
      final response = await _apiClient.get(
        '/quotes/random',
        queryParameters: {'location': location.apiValue},
      );

      final payload = response.data['data'];
      if (payload is! Map<String, dynamic>) {
        return null;
      }

      return SpiritualQuoteModel.fromJson(payload);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}
