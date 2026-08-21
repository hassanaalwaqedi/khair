import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final FlutterSecureStorage _secureStorage;

  AuthRepositoryImpl(this._remoteDataSource, this._secureStorage);

  @override
  Future<Either<Failure, AuthResponse>> login(
      String email, String password) async {
    try {
      final response = await _remoteDataSource.login(email, password);
      await _saveAuthData(response);
      return Right(response);
    } on DioException catch (e) {
      return Left(AuthFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> register(
    String email,
    String password,
    String name,
  ) async {
    try {
      final response = await _remoteDataSource.register(email, password, name);
      await _saveAuthData(response);
      return Right(response);
    } on DioException catch (e) {
      return Left(AuthFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AuthResponse>> loginWithGoogle(
    String idToken,
    String preferredLanguage,
  ) async {
    try {
      final response =
          await _remoteDataSource.loginWithGoogle(idToken, preferredLanguage);
      await _saveAuthData(response);
      return Right(response);
    } on DioException catch (e) {
      return Left(AuthFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _clearAuthData();
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    try {
      await _remoteDataSource.deleteAccount();
      await _clearAuthData();
      return const Right(null);
    } on DioException catch (e) {
      return Left(AuthFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, User?>> getCurrentUser() async {
    try {
      final userData = await _secureStorage.read(key: 'user_data');
      if (userData == null) return const Right(null);
      return Right(UserModel.fromJson(jsonDecode(userData)));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Organizer?>> getCurrentOrganizer() async {
    try {
      final organizerData = await _secureStorage.read(key: 'organizer_data');
      if (organizerData == null) return const Right(null);
      return Right(OrganizerModel.fromJson(jsonDecode(organizerData)));
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveOrganizer(Organizer organizer) async {
    try {
      await _secureStorage.write(
        key: 'organizer_data',
        value: jsonEncode(_organizerJson(organizer)),
      );
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure(e.toString()));
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.read(key: 'auth_token');
    final userData = await _secureStorage.read(key: 'user_data');
    if (token == null || token.isEmpty || userData == null) {
      await _clearAuthData();
      return false;
    }

    try {
      final segments = token.split('.');
      if (segments.length != 3) throw const FormatException('Invalid JWT');
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(segments[1]))),
      ) as Map<String, dynamic>;
      final expiresAt = payload['exp'];
      if (expiresAt is! num ||
          DateTime.fromMillisecondsSinceEpoch(
            expiresAt.toInt() * 1000,
            isUtc: true,
          ).isBefore(DateTime.now().toUtc())) {
        await _clearAuthData();
        return false;
      }
      return true;
    } catch (_) {
      await _clearAuthData();
      return false;
    }
  }

  Future<void> _clearAuthData() => Future.wait([
        _secureStorage.delete(key: 'auth_token'),
        _secureStorage.delete(key: 'user_data'),
        _secureStorage.delete(key: 'organizer_data'),
      ]);

  Future<void> _saveAuthData(AuthResponse response) async {
    await _secureStorage.write(key: 'auth_token', value: response.token);
    await _secureStorage.write(
      key: 'user_data',
      value: jsonEncode({
        'id': response.user.id,
        'email': response.user.email,
        'role': response.user.role,
        'created_at': response.user.createdAt.toIso8601String(),
        'updated_at': response.user.updatedAt.toIso8601String(),
      }),
    );
    if (response.organizer != null) {
      await _secureStorage.write(
        key: 'organizer_data',
        value: jsonEncode(_organizerJson(response.organizer!)),
      );
    } else {
      await _secureStorage.delete(key: 'organizer_data');
    }
  }

  Map<String, dynamic> _organizerJson(Organizer organizer) => {
        'id': organizer.id,
        'user_id': organizer.userId,
        'name': organizer.name,
        'description': organizer.description,
        'website': organizer.website,
        'phone': organizer.phone,
        'logo_url': organizer.logoUrl,
        'status': organizer.status,
        'rejection_reason': organizer.rejectionReason,
        'created_at': organizer.createdAt.toIso8601String(),
        'updated_at': organizer.updatedAt.toIso8601String(),
      };

  String _getErrorMessage(DioException e) {
    if (e.response?.data != null && e.response!.data is Map) {
      return e.response!.data['error'] ?? 'Authentication failed';
    }
    return e.message ?? 'Authentication failed';
  }
}
