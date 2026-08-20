import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/core/utils/image_upload_client.dart';

void main() {
  test('maps offline uploads to a retryable connection message', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/upload/image'),
      type: DioExceptionType.connectionError,
    );

    expect(imageUploadFailureMessage(error), contains('offline'));
  });

  test('maps unavailable storage responses without exposing server details',
      () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/upload/image'),
      response: Response<void>(
        requestOptions: RequestOptions(path: '/upload/image'),
        statusCode: 503,
      ),
      type: DioExceptionType.badResponse,
    );

    expect(imageUploadFailureMessage(error), contains('storage'));
  });
}
