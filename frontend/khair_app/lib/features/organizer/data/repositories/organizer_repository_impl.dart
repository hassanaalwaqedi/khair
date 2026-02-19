import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../../../events/domain/entities/event.dart';
import '../../domain/entities/organizer.dart';
import '../../domain/repositories/organizer_repository.dart';
import '../datasources/organizer_remote_datasource.dart';

/// Implementation of organizer repository
class OrganizerRepositoryImpl implements OrganizerRepository {
  final OrganizerRemoteDataSource _remoteDataSource;

  OrganizerRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, Organizer>> getMyProfile() async {
    try {
      final organizer = await _remoteDataSource.getMyProfile();
      return Right(organizer);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Organizer>> getOrganizerById(String id) async {
    try {
      final organizer = await _remoteDataSource.getOrganizerById(id);
      return Right(organizer);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Organizer>> updateProfile(UpdateProfileParams params) async {
    try {
      final organizer = await _remoteDataSource.updateProfile(params.toJson());
      return Right(organizer);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Event>>> getMyEvents() async {
    try {
      final events = await _remoteDataSource.getMyEvents();
      return Right(events);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AdminMessage>>> getAdminMessages() async {
    try {
      final messages = await _remoteDataSource.getAdminMessages();
      return Right(messages);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> markMessageAsRead(String messageId) async {
    try {
      await _remoteDataSource.markMessageAsRead(messageId);
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Organizer>> applyAsOrganizer(OrganizerApplicationParams params) async {
    try {
      final organizer = await _remoteDataSource.applyAsOrganizer(params.toJson());
      return Right(organizer);
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
