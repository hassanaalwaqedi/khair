import '../../../core/network/api_client.dart';

/// Data source for booking calendar API calls.
class BookingDatasource {
  final ApiClient _api;

  BookingDatasource(this._api);

  // ── Public: Slots ──

  Future<List<Map<String, dynamic>>> getAvailableSlots(String sheikhId, String date) async {
    final res = await _api.get('/sheikhs/$sheikhId/available-slots?date=$date');
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAvailability(String sheikhId) async {
    final res = await _api.get('/sheikhs/$sheikhId/availability');
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  // ── Sheikh: Availability ──

  Future<void> setAvailability(List<Map<String, dynamic>> rules) async {
    await _api.put('/sheikh/availability', data: {'rules': rules});
  }

  Future<void> deleteAvailability(int dayOfWeek) async {
    await _api.delete('/sheikh/availability/$dayOfWeek');
  }

  // ── Sheikh: Settings ──

  Future<Map<String, dynamic>> getBookingSettings() async {
    final res = await _api.get('/sheikh/booking-settings');
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<void> updateBookingSettings(Map<String, dynamic> settings) async {
    await _api.put('/sheikh/booking-settings', data: settings);
  }

  // ── Sheikh: Bookings ──

  Future<List<Map<String, dynamic>>> getSheikhBookings() async {
    final res = await _api.get('/sheikh/bookings');
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> respondToBooking(String bookingId, String status) async {
    await _api.post('/bookings/$bookingId/respond', data: {'status': status});
  }

  // ── Sheikh: Blocked Times ──

  Future<List<Map<String, dynamic>>> getBlockedTimes() async {
    final res = await _api.get('/sheikh/blocked-times');
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> addBlockedTime(Map<String, dynamic> data) async {
    await _api.post('/sheikh/blocked-times', data: data);
  }

  Future<void> removeBlockedTime(String id) async {
    await _api.delete('/sheikh/blocked-times/$id');
  }

  // ── Student: Bookings ──

  Future<Map<String, dynamic>> createBooking({
    required String sheikhId,
    required String startTime,
    int duration = 30,
    String? notes,
  }) async {
    final res = await _api.post('/bookings', data: {
      'sheikh_id': sheikhId,
      'start_time': startTime,
      'duration': duration,
      if (notes != null) 'notes': notes,
    });
    return res.data['data'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyBookings() async {
    final res = await _api.get('/my/bookings');
    final data = res.data['data'] as List<dynamic>? ?? [];
    return data.cast<Map<String, dynamic>>();
  }

  Future<void> cancelBooking(String bookingId) async {
    await _api.post('/bookings/$bookingId/cancel');
  }
}
