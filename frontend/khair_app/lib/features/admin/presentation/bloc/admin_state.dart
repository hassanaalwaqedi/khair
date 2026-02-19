part of 'admin_bloc.dart';

/// Status of admin operations
enum AdminStatus { initial, loading, success, failure }

/// State for admin BLoC
class AdminState extends Equatable {
  final AdminStatus status;
  final AdminStatus organizersStatus;
  final AdminStatus eventsStatus;
  final AdminStatus reportsStatus;
  final AdminStatus actionStatus;
  final List<Organizer> pendingOrganizers;
  final List<Event> pendingEvents;
  final List<Report> pendingReports;
  final String? errorMessage;

  const AdminState({
    this.status = AdminStatus.initial,
    this.organizersStatus = AdminStatus.initial,
    this.eventsStatus = AdminStatus.initial,
    this.reportsStatus = AdminStatus.initial,
    this.actionStatus = AdminStatus.initial,
    this.pendingOrganizers = const [],
    this.pendingEvents = const [],
    this.pendingReports = const [],
    this.errorMessage,
  });

  AdminState copyWith({
    AdminStatus? status,
    AdminStatus? organizersStatus,
    AdminStatus? eventsStatus,
    AdminStatus? reportsStatus,
    AdminStatus? actionStatus,
    List<Organizer>? pendingOrganizers,
    List<Event>? pendingEvents,
    List<Report>? pendingReports,
    String? errorMessage,
  }) {
    return AdminState(
      status: status ?? this.status,
      organizersStatus: organizersStatus ?? this.organizersStatus,
      eventsStatus: eventsStatus ?? this.eventsStatus,
      reportsStatus: reportsStatus ?? this.reportsStatus,
      actionStatus: actionStatus ?? this.actionStatus,
      pendingOrganizers: pendingOrganizers ?? this.pendingOrganizers,
      pendingEvents: pendingEvents ?? this.pendingEvents,
      pendingReports: pendingReports ?? this.pendingReports,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Convenience getters
  bool get isLoading => status == AdminStatus.loading;
  bool get isActionLoading => actionStatus == AdminStatus.loading;

  int get pendingOrganizerCount => pendingOrganizers.length;
  int get pendingEventCount => pendingEvents.length;
  int get pendingReportCount => pendingReports.length;
  int get totalPendingCount =>
      pendingOrganizerCount + pendingEventCount + pendingReportCount;

  @override
  List<Object?> get props => [
        status,
        organizersStatus,
        eventsStatus,
        reportsStatus,
        actionStatus,
        pendingOrganizers,
        pendingEvents,
        pendingReports,
        errorMessage,
      ];
}
