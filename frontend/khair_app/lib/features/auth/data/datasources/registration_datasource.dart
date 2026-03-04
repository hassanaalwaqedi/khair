import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';

/// Data source for registration API endpoints
class RegistrationRemoteDataSource {
  final ApiClient _apiClient;

  RegistrationRemoteDataSource(this._apiClient);

  /// Step 1: Role selection + credentials
  Future<Map<String, dynamic>> submitStep1({
    required String role,
    required String email,
    required String password,
    String? displayName,
  }) async {
    final data = <String, dynamic>{
      'role': role,
      'email': email,
      'password': password,
    };
    if (displayName != null && displayName.isNotEmpty) {
      data['display_name'] = displayName;
    }
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

  /// Verify email with 6-digit code
  Future<Map<String, dynamic>> verifyCode({
    required String email,
    required String code,
  }) async {
    final response = await _apiClient.post('/register/verify-code', data: {
      'email': email,
      'code': code,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Resend verification code
  Future<Map<String, dynamic>> resendCode({
    required String email,
  }) async {
    final response = await _apiClient.post('/register/resend-code', data: {
      'email': email,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  /// Load saved draft
  Future<Map<String, dynamic>> loadDraft(String email) async {
    final response =
        await _apiClient.get('/register/draft', queryParameters: {'email': email});
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

  /// Upload profile image
  Future<String> uploadImage(File imageFile) async {
    final fileName = imageFile.path.split('/').last;
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: fileName,
      ),
    });

    final response = await _apiClient.post('/upload/image', data: formData);
    return response.data['data']['url'] as String;
  }
}
