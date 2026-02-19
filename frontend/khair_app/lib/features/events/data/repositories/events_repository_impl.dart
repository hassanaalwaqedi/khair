import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/event.dart';
import '../../domain/repositories/events_repository.dart';
import '../datasources/events_remote_datasource.dart';

class EventsRepositoryImpl implements EventsRepository {
  final EventsRemoteDataSource _remoteDataSource;

  EventsRepositoryImpl(this._remoteDataSource);

  @override
  Future<Either<Failure, List<Event>>> getEvents(EventFilter filter) async {
    try {
      final events = await _remoteDataSource.getEvents(filter.toQueryParameters());
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
  Future<Either<Failure, List<Event>>> getNearbyEvents({
    required double latitude,
    required double longitude,
    double radius = 10,
    String? eventType,
    String? language,
    int limit = 50,
  }) async {
    try {
      final params = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
        'radius': radius.toString(),
        'limit': limit.toString(),
      };
      if (eventType != null) params['event_type'] = eventType;
      if (language != null) params['language'] = language;

      final events = await _remoteDataSource.getNearbyEvents(params);
      return Right(events);
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
  Future<Either<Failure, Event>> createEvent(CreateEventParams params) async {
    try {
      final event = await _remoteDataSource.createEvent(params.toJson());
      return Right(event);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Event>> updateEvent(String id, UpdateEventParams params) async {
    try {
      final event = await _remoteDataSource.updateEvent(id, params.toJson());
      return Right(event);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteEvent(String id) async {
    try {
      await _remoteDataSource.deleteEvent(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(ServerFailure(_getErrorMessage(e)));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Event>> submitForReview(String id) async {
    try {
      final event = await _remoteDataSource.submitForReview(id);
      return Right(event);
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
