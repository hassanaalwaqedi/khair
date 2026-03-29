part of 'admin_bloc.dart';

/// Base class for admin events
abstract class AdminEvent extends Equatable {
  const AdminEvent();

  @override
  List<Object?> get props => [];
}

/// Load all pending admin data
class LoadAdminData extends AdminEvent {
  const LoadAdminData();
}

/// Load pending organizers
class LoadPendingOrganizers extends AdminEvent {
  const LoadPendingOrganizers();
}

/// Load pending events
class LoadPendingEvents extends AdminEvent {
  const LoadPendingEvents();
}

/// Load pending reports
class LoadPendingReports extends AdminEvent {
  const LoadPendingReports();
}

/// Approve an organizer
class ApproveOrganizer extends AdminEvent {
  final String organizerId;

  const ApproveOrganizer(this.organizerId);

  @override
  List<Object?> get props => [organizerId];
}

/// Reject an organizer
class RejectOrganizer extends AdminEvent {
  final String organizerId;
  final String reason;

  const RejectOrganizer(this.organizerId, this.reason);

  @override
  List<Object?> get props => [organizerId, reason];
}

/// Approve an event
class ApproveEvent extends AdminEvent {
  final String eventId;

  const ApproveEvent(this.eventId);

  @override
  List<Object?> get props => [eventId];
}

/// Reject an event
class RejectEvent extends AdminEvent {
  final String eventId;
  final String reason;

  const RejectEvent(this.eventId, this.reason);

  @override
  List<Object?> get props => [eventId, reason];
}

/// Resolve a report
class ResolveReport extends AdminEvent {
  final String reportId;
  final String resolution;
  final String? action;

  const ResolveReport(this.reportId, this.resolution, {this.action});

  @override
  List<Object?> get props => [reportId, resolution, action];
}

/// Load all users
class LoadUsers extends AdminEvent {
  const LoadUsers();
}

/// Load dashboard stats
class LoadStats extends AdminEvent {
  const LoadStats();
}

/// Update user role
class UpdateUserRole extends AdminEvent {
  final String userId;
  final String role;

  const UpdateUserRole(this.userId, this.role);

  @override
  List<Object?> get props => [userId, role];
}

/// Update user status (suspend/ban/activate)
class UpdateUserStatus extends AdminEvent {
  final String userId;
  final String status;
  final String? reason;

  const UpdateUserStatus(this.userId, this.status, {this.reason});

  @override
  List<Object?> get props => [userId, status, reason];
}

/// Delete user
class DeleteUserEvent extends AdminEvent {
  final String userId;

  const DeleteUserEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Verify a user (mark as verified)
class VerifyUserEvent extends AdminEvent {
  final String userId;

  const VerifyUserEvent(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Send notification to all or individual user
class SendAdminNotification extends AdminEvent {
  final String title;
  final String message;
  final String target; // 'all' or 'individual'
  final String? userId;

  const SendAdminNotification({
    required this.title,
    required this.message,
    required this.target,
    this.userId,
  });

  @override
  List<Object?> get props => [title, message, target, userId];
}

/// Search users for notification user picker
class SearchUsersForNotification extends AdminEvent {
  final String query;

  const SearchUsersForNotification(this.query);

  @override
  List<Object?> get props => [query];
}

/// Load pending verification requests
class LoadVerifications extends AdminEvent {
  const LoadVerifications();
}

/// Review a verification request (approve/reject/request changes)
class ReviewVerificationEvent extends AdminEvent {
  final String requestId;
  final String status; // approved, rejected, more_info_needed
  final String? reviewNotes;

  const ReviewVerificationEvent(this.requestId, this.status, {this.reviewNotes});

  @override
  List<Object?> get props => [requestId, status, reviewNotes];
}
