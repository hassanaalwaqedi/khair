import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'image_upload_validator.dart';

/// Uses one multipart contract for all public images (event covers, avatars,
/// and verification photos). Keeping the timeout and response parsing here
/// prevents each screen from subtly behaving differently.
Future<String> uploadImageBytes({
  required Dio dio,
  required String path,
  required Uint8List bytes,
  required String filename,
  ProgressCallback? onSendProgress,
}) async {
  final response = await dio.post(
    path,
    data: FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    }),
    options: Options(
      contentType: 'multipart/form-data',
      sendTimeout: const Duration(minutes: 2),
      receiveTimeout: const Duration(minutes: 2),
    ),
    onSendProgress: onSendProgress,
  );

  final body = response.data;
  final data = body is Map ? body['data'] : null;
  final url = data is Map ? data['url']?.toString() : null;
  if (url == null || url.isEmpty) {
    throw const FormatException(
        'The upload service did not return an image URL.');
  }
  return url;
}

String imageUploadIssueMessage(ImageUploadIssue issue) {
  switch (issue) {
    case ImageUploadIssue.empty:
      return 'The selected image is empty. Choose another photo.';
    case ImageUploadIssue.tooLarge:
      return 'Choose an image smaller than 5 MB.';
    case ImageUploadIssue.unsupportedType:
      return 'Use a JPG, PNG, or WebP image.';
    case ImageUploadIssue.invalidImage:
      return 'This image appears to be invalid. Choose another photo.';
  }
}

String imageUploadFailureMessage(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
        return 'Unable to upload while offline. Check your connection and retry.';
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The upload took too long. Please retry.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        if (status == 401) return 'Your session expired. Please sign in again.';
        if (status == 413) return 'Choose an image smaller than 5 MB.';
        if (status == 500 || status == 503) {
          return 'Image storage is temporarily unavailable. Please try again shortly.';
        }
        break;
      default:
        break;
    }
  }
  if (error is FormatException) return error.message.toString();
  return 'We could not upload that image. Please try again.';
}
