import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/image_upload_client.dart';
import '../../../../core/utils/image_upload_validator.dart';

/// Data source for registration API endpoints
class RegistrationRemoteDataSource {
  final ApiClient _apiClient;

  RegistrationRemoteDataSource(this._apiClient);

  /// Minimal attendee signup. Organizer access is always a later application.
  Future<Map<String, dynamic>> submitStep1({
    required String email,
    required String password,
    required String displayName,
    required String preferredLanguage,
  }) async {
    final data = <String, dynamic>{
      'role': 'user',
      'email': email,
      'password': password,
      'display_name': displayName,
      'preferred_language': preferredLanguage,
    };
    final response = await _apiClient.post('/register/step1', data: data);
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Step 2: Basic profile info
  Future<Map<String, dynamic>> submitStep2({
    required String draftId,
    required String displayName,
    String? bio,
    String? location,
    String? city,
    String? country,
    String? language,
  }) async {
    final response = await _apiClient.post('/register/step2', data: {
      'draft_id': draftId,
      'display_name': displayName,
      'bio': bio ?? '',
      'location': location ?? '',
      'city': city ?? '',
      'country': country ?? '',
      'preferred_language': language ?? 'en',
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Step 3: Role-specific info
  Future<Map<String, dynamic>> submitStep3({
    required String draftId,
    required Map<String, dynamic> data,
  }) async {
    final response = await _apiClient.post('/register/step3', data: {
      'draft_id': draftId,
      'data': data,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Step 4: Complete registration
  Future<Map<String, dynamic>> submitStep4({
    required String draftId,
  }) async {
    final response = await _apiClient.post('/register/step4', data: {
      'draft_id': draftId,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyCode({
    required String email,
    required String code,
  }) async {
    final response = await _apiClient.post('/register/verify-code', data: {
      'email': email,
      'code': code,
    });
    final data = response.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {'message': data?.toString() ?? 'Verified'};
  }

  Future<Map<String, dynamic>> resendCode({
    required String email,
  }) async {
    final response = await _apiClient.post('/register/resend-code', data: {
      'email': email,
    });
    final data = response.data['data'];
    if (data is Map<String, dynamic>) return data;
    return {'message': data?.toString() ?? 'Code sent'};
  }

  /// Load saved draft
  Future<Map<String, dynamic>> loadDraft(String email) async {
    final response = await _apiClient
        .get('/register/draft', queryParameters: {'email': email});
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Get smart suggestions
  Future<Map<String, dynamic>> getSuggestions({
    required String role,
    required Map<String, dynamic> data,
  }) async {
    final response = await _apiClient.post('/register/suggestions', data: {
      'role': role,
      'data': data,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Upload profile image using bytes (web-compatible)
  Future<String> uploadImageBytes(Uint8List bytes, String filename) async {
    final issue = await inspectImageUpload(filename: filename, bytes: bytes);
    if (issue != null) throw ArgumentError(imageUploadIssueMessage(issue));
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        bytes,
        filename: filename,
      ),
    });

    final response = await _apiClient.post(
      '/upload/image',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    final data = response.data['data'];
    final url = data is Map ? data['url']?.toString() : null;
    if (url == null || url.isEmpty) {
      throw const FormatException(
          'The upload service did not return an image URL.');
    }
    return url;
  }
}
