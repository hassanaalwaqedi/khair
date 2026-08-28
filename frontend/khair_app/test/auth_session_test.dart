import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khair_app/core/auth/auth_session_controller.dart';
import 'package:khair_app/core/network/auth_interceptor.dart';
import 'package:khair_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:khair_app/features/auth/presentation/bloc/auth_bloc.dart';

void main() {
  group('401 session boundary', () {
    test('failed login does not expire an existing session', () {
      final error = _unauthorized('/api/v1/auth/login');

      expect(shouldExpireAuthSession(error), isFalse);
    });

    test('failed staged registration does not expire an existing session', () {
      final request = RequestOptions(
        path: '/api/v1/register/step1',
        headers: {'Authorization': 'Bearer stale-token'},
      );
      final error = DioException(
        requestOptions: request,
        response: Response<void>(requestOptions: request, statusCode: 401),
      );

      expect(shouldExpireAuthSession(error), isFalse);
    });

    test('unauthorized protected request expires the session', () {
      final error = _unauthorized('/api/v1/me/profile-overview');

      expect(shouldExpireAuthSession(error), isTrue);
    });

    test('unauthorized request without a bearer token is not a session expiry',
        () {
      final error = _unauthorized(
        '/api/v1/me/profile-overview',
        includeBearerToken: false,
      );

      expect(shouldExpireAuthSession(error), isFalse);
    });
  });

  test('AuthBloc becomes unauthenticated when the HTTP layer expires session',
      () async {
    final controller = AuthSessionController();
    final bloc = AuthBloc(_FakeAuthRepository(), controller);

    controller.notifyExpired();
    
    // Give the bloc time to process the event
    await Future.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.status, AuthStatus.unauthenticated);
    expect(bloc.state.user, isNull);
    
    await bloc.close();
    await controller.dispose();
  });
}

DioException _unauthorized(
  String path, {
  bool includeBearerToken = true,
}) {
  final options = RequestOptions(
    path: path,
    headers: {
      if (includeBearerToken) 'Authorization': 'Bearer expired-token',
    },
  );
  return DioException(
    requestOptions: options,
    response: Response<void>(
      requestOptions: options,
      statusCode: 401,
    ),
    type: DioExceptionType.badResponse,
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
