import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../organizer/domain/entities/organizer.dart';
import '../../../events/domain/entities/event.dart';
import '../entities/admin_entities.dart';

/// Repository interface for admin operations
abstract class AdminRepository {
  /// Get admin dashboard stats
  Future<Either<Failure, AdminStats>> getStats();

  /// Get pending organizers for review
  Future<Either<Failure, List<Organizer>>> getPendingOrganizers();

  /// Get all organizers
  Future<Either<Failure, List<Organizer>>> getAllOrganizers();

  /// Get organizer by ID
  Future<Either<Failure, Organizer>> getOrganizerById(String id);

  /// Update organizer status (approve/reject)
  Future<Either<Failure, Organizer>> updateOrganizerStatus(
    String id,
    StatusUpdateParams params,
  );

  /// Get pending events for review
  Future<Either<Failure, List<Event>>> getPendingEvents();

  /// Get event by ID for admin review
  Future<Either<Failure, Event>> getEventById(String id);

  /// Update event status (approve/reject)
  Future<Either<Failure, Event>> updateEventStatus(
    String id,
    StatusUpdateParams params,
  );

  /// Get pending reports
  Future<Either<Failure, List<Report>>> getPendingReports();

  /// Resolve a report
  Future<Either<Failure, Report>> resolveReport(
    String id,
    ReportResolutionParams params,
  );
}

/// Parameters for status update
class StatusUpdateParams {
  final String status; // approved, rejected
  final String? reason;

  const StatusUpdateParams({
    required this.status,
    this.reason,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'status': status};
    if (reason != null) map['reason'] = reason;
    return map;
  }
}

/// Parameters for report resolution
class ReportResolutionParams {
  final String resolution;
  final String? action; // warn, suspend, none

  const ReportResolutionParams({
    required this.resolution,
    this.action,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'resolution': resolution};
    if (action != null) map['action'] = action;
    return map;
  }
}
