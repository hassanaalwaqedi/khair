import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/di/injection.dart';
import '../../../core/network/api_client.dart';

/// API client for the production organizer trust gateway. Drafts, uploads and
/// decisions are all server-backed; this class deliberately has no local/mock
/// fallback so users never see a pretend application state.
class OrganizerApplicationApi {
  OrganizerApplicationApi({ApiClient? client})
      : _client = client ?? getIt<ApiClient>();

  final ApiClient _client;

  Future<Map<String, dynamic>?> loadMine() async {
    try {
      final response = await _client.get('organizer/application/me');
      return Map<String, dynamic>.from(response.data['data'] as Map);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> saveDraft(Map<String, dynamic> draft) async {
    final response =
        await _client.put('organizer/application/me', data: draft);
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> submit({required bool resubmit}) async {
    final response = await _client.post(
      resubmit
          ? 'organizer/application/me/resubmit'
          : 'organizer/application/me/submit',
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> uploadImage({
    required Uint8List bytes,
    required String filename,
    required bool representativePhoto,
    ProgressCallback? onSendProgress,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _client.post(
      representativePhoto
          ? 'organizer/application/me/representative-photo'
          : 'organizer/application/me/logo',
      data: form,
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
      onSendProgress: onSendProgress,
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> uploadDocument({
    required Uint8List bytes,
    required String filename,
    required String fileType,
    String? note,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
      'file_type': fileType,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    final response = await _client.post(
      'organizer/application/me/documents',
      data: form,
      options: Options(
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }
}
