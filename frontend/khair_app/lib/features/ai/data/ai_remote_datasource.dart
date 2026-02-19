import '../../../../core/network/api_client.dart';

/// Data source for AI personalization endpoints
abstract class AiRemoteDataSource {
  /// Log a user interaction signal
  Future<void> logInteraction({
    String? eventId,
    required String interactionType,
    Map<String, dynamic>? metadata,
  });

  /// Get AI-ranked event recommendations
  Future<Map<String, dynamic>> getRecommendations({int limit = 10});

  /// Perform AI-enhanced smart search
  Future<Map<String, dynamic>> smartSearch(String query);

  /// Enhance an event description using AI
  Future<Map<String, dynamic>> enhanceDescription({
    required String title,
    required String description,
    List<String>? tags,
  });

  /// Auto-detect event category from description
  Future<Map<String, dynamic>> detectCategory({
    required String title,
    required String description,
  });

  /// Get AI system status
  Future<Map<String, dynamic>> getAiStatus();
}

class AiRemoteDataSourceImpl implements AiRemoteDataSource {
  final ApiClient _apiClient;

  AiRemoteDataSourceImpl(this._apiClient);

  @override
  Future<void> logInteraction({
    String? eventId,
    required String interactionType,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _apiClient.post('/ai/interactions', data: {
        if (eventId != null) 'event_id': eventId,
        'interaction_type': interactionType,
        if (metadata != null) 'metadata': metadata,
      });
    } catch (_) {
      // Silently fail — interaction logging should never break UX
    }
  }

  @override
  Future<Map<String, dynamic>> getRecommendations({int limit = 10}) async {
    final response = await _apiClient.get(
      '/ai/recommendations',
      queryParameters: {'limit': limit},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> smartSearch(String query) async {
    final response = await _apiClient.post('/ai/smart-search', data: {
      'query': query,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> enhanceDescription({
    required String title,
    required String description,
    List<String>? tags,
  }) async {
    final response = await _apiClient.post('/ai/enhance-description', data: {
      'title': title,
      'description': description,
      if (tags != null) 'tags': tags,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> detectCategory({
    required String title,
    required String description,
  }) async {
    final response = await _apiClient.post('/ai/detect-category', data: {
      'title': title,
      'description': description,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getAiStatus() async {
    final response = await _apiClient.get('/ai/status');
    return response.data['data'] as Map<String, dynamic>;
  }
}
