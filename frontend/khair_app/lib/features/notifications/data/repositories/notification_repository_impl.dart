import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/notification_entity.dart';
import '../datasources/notification_remote_datasource.dart';

/// Repository interface for notifications
abstract class NotificationRepository {
  Future<Either<Failure, List<AppNotification>>> getNotifications();
  Future<Either<Failure, int>> getUnreadCount();
  Future<Either<Failure, void>> markAsRead(String id);
  Future<Either<Failure, void>> markAllRead();
}

/// Implementation of notification repository
class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remoteDataSource;

  NotificationRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<AppNotification>>> getNotifications() async {
    try {
      final notifications = await _remoteDataSource.getNotifications();
      return Right(notifications);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadCount() async {
    try {
      final count = await _remoteDataSource.getUnreadCount();
      return Right(count);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRead(String id) async {
    try {
      await _remoteDataSource.markAsRead(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markAllRead() async {
    try {
      await _remoteDataSource.markAllRead();
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  String _getErrorMessage(DioException e) {
    if (e.response?.data != null && e.response!.data is Map) {
      return e.response!.data['error'] ?? 'An error occurred';
    }
    return e.message ?? 'An error occurred';
  }
}
