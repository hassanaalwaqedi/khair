import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/auth_session_controller.dart';

class AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _secureStorage;
  final AuthSessionController _sessionController;

  AuthInterceptor(this._secureStorage, this._sessionController);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Login/registration requests establish a new identity and must not carry
    // a possibly stale Bearer token from a previous browser session.
    final token = _isPublicAuthRequest(options.path)
        ? null
        : await _secureStorage.read(key: 'auth_token');

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (shouldExpireAuthSession(err)) {
      await Future.wait([
        _secureStorage.delete(key: 'auth_token'),
        _secureStorage.delete(key: 'user_data'),
        _secureStorage.delete(key: 'organizer_data'),
      ]);
      _sessionController.notifyExpired();
    }
    handler.next(err);
  }
}

bool _isPublicAuthRequest(String path) {
  final normalized = Uri.tryParse(path)?.path ?? path;
  return normalized.endsWith('/auth/login') ||
      normalized.endsWith('/auth/register') ||
      normalized.endsWith('/auth/google') ||
      normalized.endsWith('/auth/verify-email') ||
      normalized.endsWith('/auth/resend-otp') ||
      normalized.contains('/register/') ||
      normalized.contains('/join-register/');
}

/// Exposed for regression tests around the security-sensitive 401 boundary.
bool shouldExpireAuthSession(DioException error) {
  if (error.response?.statusCode != 401 ||
      _isPublicAuthRequest(error.requestOptions.path)) {
    return false;
  }
  final authorization = error.requestOptions.headers['Authorization'];
  return authorization is String && authorization.startsWith('Bearer ');
}
