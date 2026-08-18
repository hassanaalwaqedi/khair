import '../../../../core/network/api_client.dart';
import '../../domain/entities/organizer.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/data/models/event_model.dart';

/// Remote data source for organizer API calls
abstract class OrganizerRemoteDataSource {
  Future<Organizer> getMyProfile();
  Future<Organizer> getOrganizerById(String id);
  Future<Organizer> updateProfile(Map<String, dynamic> data);
  Future<List<Event>> getMyEvents();
  Future<List<AdminMessage>> getAdminMessages();
  Future<void> markMessageAsRead(String messageId);
  Future<Organizer> applyAsOrganizer(Map<String, dynamic> data);
}

/// Implementation of organizer remote data source
class OrganizerRemoteDataSourceImpl implements OrganizerRemoteDataSource {
  final ApiClient _apiClient;

  OrganizerRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Organizer> getMyProfile() async {
    final response = await _apiClient.get('/organizers/me');
    return Organizer.fromJson(response.data['data']);
  }

  @override
  Future<Organizer> getOrganizerById(String id) async {
    final response = await _apiClient.get('/organizers/$id');
    return Organizer.fromJson(response.data['data']);
  }

  @override
  Future<Organizer> updateProfile(Map<String, dynamic> data) async {
    final response = await _apiClient.put('/organizers/me', data: data);
    return Organizer.fromJson(response.data['data']);
  }

  @override
  Future<List<Event>> getMyEvents() async {
    final response = await _apiClient.get('/my/events');
    final List<dynamic> eventsList = response.data['data'] ?? [];
    return eventsList.map((json) => EventModel.fromJson(json)).toList();
  }

  @override
  Future<List<AdminMessage>> getAdminMessages() async {
    final response = await _apiClient.get('/organizers/me/messages');
    final List<dynamic> messagesList = response.data['data'] ?? [];
    return messagesList.map((json) => AdminMessage.fromJson(json)).toList();
  }

  @override
  Future<void> markMessageAsRead(String messageId) async {
    await _apiClient.put('/organizers/me/messages/$messageId/read');
  }

  @override
  Future<Organizer> applyAsOrganizer(Map<String, dynamic> data) async {
    final response = await _apiClient.post('/auth/register-organizer', data: {
      'organization_name': data['name'],
      'description': data['description'],
      'country': data['country'],
      'city': data['city'],
      'contact_email': data['email'],
      'website': data['website'],
    });
    return Organizer.fromJson(response.data['data']);
  }
}
