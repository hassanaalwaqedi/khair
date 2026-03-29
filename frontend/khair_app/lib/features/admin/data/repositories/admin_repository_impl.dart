import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../../../organizer/domain/entities/organizer.dart';
import '../../../events/domain/entities/event.dart';
import '../../domain/entities/admin_entities.dart';
import '../../domain/repositories/admin_repository.dart';
import '../datasources/admin_remote_datasource.dart';

/// Implementation of admin repository
class AdminRepositoryImpl implements AdminRepository {
  final AdminRemoteDataSource _remoteDataSource;

  AdminRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, AdminStats>> getStats() async {
    try {
      final stats = await _remoteDataSource.getStats();
      return Right(stats);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Organizer>>> getPendingOrganizers() async {
    try {
      final organizers = await _remoteDataSource.getPendingOrganizers();
      return Right(organizers);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Organizer>>> getAllOrganizers() async {
    try {
      final organizers = await _remoteDataSource.getAllOrganizers();
      return Right(organizers);
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
  Future<Either<Failure, Organizer>> updateOrganizerStatus(
    String id,
    StatusUpdateParams params,
  ) async {
    try {
      final organizer = await _remoteDataSource.updateOrganizerStatus(id, params.toJson());
      return Right(organizer);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Event>>> getPendingEvents() async {
    try {
      final events = await _remoteDataSource.getPendingEvents();
      return Right(events);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Event>> getEventById(String id) async {
    try {
      final event = await _remoteDataSource.getEventById(id);
      return Right(event);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Event>> updateEventStatus(
    String id,
    StatusUpdateParams params,
  ) async {
    try {
      final event = await _remoteDataSource.updateEventStatus(id, params.toJson());
      return Right(event);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Report>>> getPendingReports() async {
    try {
      final reports = await _remoteDataSource.getPendingReports();
      return Right(reports);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Report>> resolveReport(
    String id,
    ReportResolutionParams params,
  ) async {
    try {
      final report = await _remoteDataSource.resolveReport(id, params.toJson());
      return Right(report);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AdminUser>>> getAllUsers() async {
    try {
      final users = await _remoteDataSource.getAllUsers();
      return Right(users);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateUserRole(String userId, String role) async {
    try {
      await _remoteDataSource.updateUserRole(userId, role);
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> updateUserStatus(String userId, String status, {String? reason}) async {
    try {
      await _remoteDataSource.updateUserStatus(userId, status, reason: reason);
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(String userId) async {
    try {
      await _remoteDataSource.deleteUser(userId);
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> verifyUser(String userId) async {
    try {
      await _remoteDataSource.verifyUser(userId);
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> sendNotification({
    required String title,
    required String message,
    required String target,
    String? userId,
  }) async {
    try {
      final count = await _remoteDataSource.sendNotification(
        title: title,
        message: message,
        target: target,
        userId: userId,
      );
      return Right(count);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchUsersForNotification(String query) async {
    try {
      final users = await _remoteDataSource.searchUsersForNotification(query);
      return Right(users);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<VerificationRequest>>> getPendingVerifications() async {
    try {
      final requests = await _remoteDataSource.getPendingVerifications();
      return Right(requests);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> reviewVerification(String id, String status, {String? reviewNotes}) async {
    try {
      await _remoteDataSource.reviewVerification(id, status, reviewNotes: reviewNotes);
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
