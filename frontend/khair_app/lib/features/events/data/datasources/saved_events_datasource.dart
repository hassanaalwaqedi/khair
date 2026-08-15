import '../../../../core/network/api_client.dart';

/// Server-backed saved-event state shared by all future event surfaces.
class SavedEventsDataSource {
  SavedEventsDataSource(this._api);

  final ApiClient _api;

  Future<bool> isSaved(String eventId) async {
    final response = await _api.get('/events/$eventId/saved');
    final data = response.data['data'] as Map<String, dynamic>?;
    return data?['saved'] == true;
  }

  Future<bool> toggle(String eventId, {required bool saved}) async {
    final response = saved
        ? await _api.delete('/events/$eventId/save')
        : await _api.post('/events/$eventId/save');
    final data = response.data['data'] as Map<String, dynamic>?;
    return data?['saved'] == true;
  }
}
