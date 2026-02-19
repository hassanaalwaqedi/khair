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
