import '../../../../core/network/api_client.dart';
import '../../../organizer/domain/entities/organizer.dart';
import '../../../events/domain/entities/event.dart';
import '../../domain/entities/admin_entities.dart';

/// Remote data source for admin API calls
abstract class AdminRemoteDataSource {
  Future<AdminStats> getStats();
  Future<List<Organizer>> getPendingOrganizers();
  Future<List<Organizer>> getAllOrganizers();
  Future<Organizer> getOrganizerById(String id);
  Future<Organizer> updateOrganizerStatus(String id, Map<String, dynamic> data);
  Future<List<Event>> getPendingEvents();
  Future<Event> getEventById(String id);
  Future<Event> updateEventStatus(String id, Map<String, dynamic> data);
  Future<List<Report>> getPendingReports();
  Future<Report> resolveReport(String id, Map<String, dynamic> data);
  Future<List<AdminUser>> getAllUsers();
  Future<void> updateUserRole(String userId, String role);
  Future<void> updateUserStatus(String userId, String status, {String? reason});
  Future<void> deleteUser(String userId);
  Future<void> verifyUser(String userId);
  Future<int> sendNotification({required String title, required String message, required String target, String? userId});
  Future<List<Map<String, dynamic>>> searchUsersForNotification(String query);
}

/// Implementation of admin remote data source
class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  final ApiClient _apiClient;

  AdminRemoteDataSourceImpl(this._apiClient);

  @override
  Future<AdminStats> getStats() async {
    final response = await _apiClient.get('/admin/stats');
    return AdminStats.fromJson(response.data['data'] ?? {});
  }

  @override
  Future<List<Organizer>> getPendingOrganizers() async {
    final response = await _apiClient.get('/admin/organizers/pending');
    final List<dynamic> list = response.data['data'] ?? [];
    return list.map((json) => Organizer.fromJson(json)).toList();
  }

  @override
  Future<List<Organizer>> getAllOrganizers() async {
    final response = await _apiClient.get('/admin/organizers');
    final List<dynamic> list = response.data['data'] ?? [];
    return list.map((json) => Organizer.fromJson(json)).toList();
  }

  @override
  Future<Organizer> getOrganizerById(String id) async {
    final response = await _apiClient.get('/admin/organizers/$id');
    return Organizer.fromJson(response.data['data']);
  }

  @override
  Future<Organizer> updateOrganizerStatus(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/admin/organizers/$id/status', data: data);
    return Organizer.fromJson(response.data['data']);
  }

  @override
  Future<List<Event>> getPendingEvents() async {
    final response = await _apiClient.get('/admin/events/pending');
    final List<dynamic> list = response.data['data'] ?? [];
    return list
        .map((json) => Event(
              id: json['id'],
              organizerId: json['organizer_id'],
              title: json['title'],
              description: json['description'],
              eventType: json['event_type'],
              language: json['language'],
              country: json['country'],
              city: json['city'],
              address: json['address'],
              latitude: json['latitude']?.toDouble(),
              longitude: json['longitude']?.toDouble(),
              startDate: DateTime.parse(json['start_date']),
              endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
              imageUrl: json['image_url'],
              status: json['status'],
              rejectionReason: json['rejection_reason'],
              organizerName: json['organizer_name'],
              createdAt: DateTime.parse(json['created_at']),
              updatedAt: DateTime.parse(json['updated_at']),
            ))
        .toList();
  }

  @override
  Future<Event> getEventById(String id) async {
    final response = await _apiClient.get('/admin/events/$id');
    final json = response.data['data'];
    return Event(
      id: json['id'],
      organizerId: json['organizer_id'],
      title: json['title'],
      description: json['description'],
      eventType: json['event_type'],
      language: json['language'],
      country: json['country'],
      city: json['city'],
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      imageUrl: json['image_url'],
      status: json['status'],
      rejectionReason: json['rejection_reason'],
      organizerName: json['organizer_name'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  @override
  Future<Event> updateEventStatus(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/admin/events/$id/status', data: data);
    final json = response.data['data'];
    return Event(
      id: json['id'],
      organizerId: json['organizer_id'],
      title: json['title'],
      description: json['description'],
      eventType: json['event_type'],
      language: json['language'],
      country: json['country'],
      city: json['city'],
      address: json['address'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      imageUrl: json['image_url'],
      status: json['status'],
      rejectionReason: json['rejection_reason'],
      organizerName: json['organizer_name'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  @override
  Future<List<Report>> getPendingReports() async {
    final response = await _apiClient.get('/admin/reports/pending');
    final List<dynamic> list = response.data['data'] ?? [];
    return list.map((json) => Report.fromJson(json)).toList();
  }

  @override
  Future<Report> resolveReport(String id, Map<String, dynamic> data) async {
    final response = await _apiClient.put('/admin/reports/$id/resolve', data: data);
    return Report.fromJson(response.data['data']);
  }

  @override
  Future<List<AdminUser>> getAllUsers() async {
    final response = await _apiClient.get('/admin/users');
    final List<dynamic> list = response.data['data'] ?? [];
    return list.map((json) => AdminUser.fromJson(json)).toList();
  }

  @override
  Future<void> updateUserRole(String userId, String role) async {
    await _apiClient.put('/admin/users/$userId/role', data: {'role': role});
  }

  @override
  Future<void> updateUserStatus(String userId, String status, {String? reason}) async {
    await _apiClient.put('/admin/users/$userId/status', data: {
      'status': status,
      if (reason != null) 'reason': reason,
    });
  }

  @override
  Future<void> deleteUser(String userId) async {
    await _apiClient.delete('/admin/users/$userId');
  }

  @override
  Future<void> verifyUser(String userId) async {
    await _apiClient.put('/admin/users/$userId/verify');
  }

  @override
  Future<int> sendNotification({required String title, required String message, required String target, String? userId}) async {
    final response = await _apiClient.post('/admin/notifications/send', data: {
      'title': title,
      'message': message,
      'target': target,
      if (userId != null) 'user_id': userId,
    });
    return response.data['data']?['recipients_count'] ?? 0;
  }

  @override
  Future<List<Map<String, dynamic>>> searchUsersForNotification(String query) async {
    final response = await _apiClient.get('/admin/users/search', queryParameters: {'q': query});
    final List<dynamic> list = response.data['data'] ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
