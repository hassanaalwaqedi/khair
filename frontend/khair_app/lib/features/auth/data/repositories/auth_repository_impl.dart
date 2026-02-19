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
  Future<Either<Failure, AuthResponse>> login(String email, String password) async {
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
  Future<Either<Failure, void>> logout() async {
    try {
      await _secureStorage.delete(key: 'auth_token');
      await _secureStorage.delete(key: 'user_data');
      return const Right(null);
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
  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.read(key: 'auth_token');
    return token != null;
  }

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
  }

  String _getErrorMessage(DioException e) {
    if (e.response?.data != null && e.response!.data is Map) {
      return e.response!.data['error'] ?? 'Authentication failed';
    }
    return e.message ?? 'Authentication failed';
  }
}
