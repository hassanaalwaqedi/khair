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

  /// Get all users for admin management
  Future<Either<Failure, List<AdminUser>>> getAllUsers();

  /// Update user role (promote to organizer/admin)
  Future<Either<Failure, void>> updateUserRole(String userId, String role);

  /// Update user status (suspend/ban/activate)
  Future<Either<Failure, void>> updateUserStatus(String userId, String status, {String? reason});

  /// Delete user
  Future<Either<Failure, void>> deleteUser(String userId);

  /// Verify user (mark as verified)
  Future<Either<Failure, void>> verifyUser(String userId);

  /// Send notification to all users or individual user
  Future<Either<Failure, int>> sendNotification({
    required String title,
    required String message,
    required String target,
    String? userId,
  });

  /// Search users for notification user picker
  Future<Either<Failure, List<Map<String, dynamic>>>> searchUsersForNotification(String query);

  /// Get pending verification requests
  Future<Either<Failure, List<VerificationRequest>>> getPendingVerifications();

  /// Review a verification request (approve/reject/more_info_needed)
  Future<Either<Failure, void>> reviewVerification(String id, String status, {String? reviewNotes});
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
    if (reason != null) map['rejection_reason'] = reason;
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
