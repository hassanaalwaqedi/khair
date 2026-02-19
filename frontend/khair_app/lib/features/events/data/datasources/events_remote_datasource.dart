import '../../../../core/network/api_client.dart';
import '../models/event_model.dart';

abstract class EventsRemoteDataSource {
  Future<List<EventModel>> getEvents(Map<String, dynamic> queryParams);
  Future<EventModel> getEventById(String id);
  Future<List<EventModel>> getNearbyEvents(Map<String, dynamic> queryParams);
  Future<List<EventModel>> getMyEvents();
  Future<EventModel> createEvent(Map<String, dynamic> data);
  Future<EventModel> updateEvent(String id, Map<String, dynamic> data);
  Future<void> deleteEvent(String id);
  Future<EventModel> submitForReview(String id);
}

class EventsRemoteDataSourceImpl implements EventsRemoteDataSource {
  final ApiClient _apiClient;

  EventsRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<EventModel>> getEvents(Map<String, dynamic> queryParams) async {
    final response = await _apiClient.get('/events', queryParameters: queryParams);
    final data = response.data['data'] as List;
    return data.map((e) => EventModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<EventModel> getEventById(String id) async {
    final response = await _apiClient.get('/events/$id');
    return EventModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<List<EventModel>> getNearbyEvents(Map<String, dynamic> queryParams) async {
    final response = await _apiClient.get('/map/nearby', queryParameters: queryParams);
    final data = response.data['data'] as List;
    return data.map((e) => EventModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<EventModel>> getMyEvents() async {
    final response = await _apiClient.get('/my/events');
    final data = response.data['data'] as List;
    return data.map((e) => EventModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<EventModel> createEvent(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/events', data: data);
    return EventModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<EventModel> updateEvent(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/events/$id', data: data);
    return EventModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<void> deleteEvent(String id) async {
    await _apiClient.delete('/events/$id');
  }

  @override
  Future<EventModel> submitForReview(String id) async {
    final response = await _apiClient.post('/events/$id/submit');
    return EventModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }
}
