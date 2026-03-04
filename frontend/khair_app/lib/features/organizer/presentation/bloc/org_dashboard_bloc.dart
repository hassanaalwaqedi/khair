import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../data/datasources/org_dashboard_datasource.dart';

// ── Events ──

abstract class OrgDashEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadDashboard extends OrgDashEvent {}
class LoadAnalytics extends OrgDashEvent {}
class LoadActivity extends OrgDashEvent {}

class LoadEvents extends OrgDashEvent {
  final String? statusFilter;
  final int page;
  LoadEvents({this.statusFilter, this.page = 1});
  @override
  List<Object?> get props => [statusFilter, page];
}

class CreateEvent extends OrgDashEvent {
  final Map<String, dynamic> data;
  CreateEvent(this.data);
}

class UpdateEvent extends OrgDashEvent {
  final String eventId;
  final Map<String, dynamic> data;
  UpdateEvent(this.eventId, this.data);
}

class CancelEvent extends OrgDashEvent {
  final String eventId;
  CancelEvent(this.eventId);
}

class DuplicateEvent extends OrgDashEvent {
  final String eventId;
  DuplicateEvent(this.eventId);
}

class LoadAttendees extends OrgDashEvent {
  final String eventId;
  final String? search;
  final String? statusFilter;
  final int page;
  LoadAttendees(this.eventId, {this.search, this.statusFilter, this.page = 1});
  @override
  List<Object?> get props => [eventId, search, statusFilter, page];
}

class MarkAttendance extends OrgDashEvent {
  final String eventId;
  final String regId;
  final bool attended;
  MarkAttendance(this.eventId, this.regId, this.attended);
}

class RemoveAttendee extends OrgDashEvent {
  final String eventId;
  final String regId;
  RemoveAttendee(this.eventId, this.regId);
}

class LoadProfile extends OrgDashEvent {}

class UpdateProfile extends OrgDashEvent {
  final Map<String, dynamic> data;
  UpdateProfile(this.data);
}

class LoadMembers extends OrgDashEvent {}

class AddMember extends OrgDashEvent {
  final String email;
  final String role;
  AddMember(this.email, this.role);
}

class UpdateMemberRole extends OrgDashEvent {
  final String memberId;
  final String role;
  UpdateMemberRole(this.memberId, this.role);
}

class RemoveMember extends OrgDashEvent {
  final String memberId;
  RemoveMember(this.memberId);
}

// ── State ──

class OrgDashState extends Equatable {
  final bool isLoading;
  final String? error;
  final String? successMessage;
  final Map<String, dynamic>? dashboardStats;
  final Map<String, dynamic>? analyticsData;
  final List<dynamic>? activityLog;
  final List<dynamic>? events;
  final int eventsTotalCount;
  final List<dynamic>? attendees;
  final int attendeesTotalCount;
  final Map<String, dynamic>? profile;
  final List<dynamic>? members;

  const OrgDashState({
    this.isLoading = false,
    this.error,
    this.successMessage,
    this.dashboardStats,
    this.analyticsData,
    this.activityLog,
    this.events,
    this.eventsTotalCount = 0,
    this.attendees,
    this.attendeesTotalCount = 0,
    this.profile,
    this.members,
  });

  OrgDashState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    Map<String, dynamic>? dashboardStats,
    Map<String, dynamic>? analyticsData,
    List<dynamic>? activityLog,
    List<dynamic>? events,
    int? eventsTotalCount,
    List<dynamic>? attendees,
    int? attendeesTotalCount,
    Map<String, dynamic>? profile,
    List<dynamic>? members,
  }) {
    return OrgDashState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
      dashboardStats: dashboardStats ?? this.dashboardStats,
      analyticsData: analyticsData ?? this.analyticsData,
      activityLog: activityLog ?? this.activityLog,
      events: events ?? this.events,
      eventsTotalCount: eventsTotalCount ?? this.eventsTotalCount,
      attendees: attendees ?? this.attendees,
      attendeesTotalCount: attendeesTotalCount ?? this.attendeesTotalCount,
      profile: profile ?? this.profile,
      members: members ?? this.members,
    );
  }

  @override
  List<Object?> get props => [
        isLoading, error, successMessage, dashboardStats, analyticsData,
        activityLog, events, eventsTotalCount, attendees, attendeesTotalCount,
        profile, members,
      ];
}

// ── BLoC ──

class OrgDashBloc extends Bloc<OrgDashEvent, OrgDashState> {
  final OrgDashboardDatasource datasource;
  final String orgId;

  OrgDashBloc({required this.datasource, required this.orgId})
      : super(const OrgDashState()) {
    on<LoadDashboard>(_onLoadDashboard);
    on<LoadAnalytics>(_onLoadAnalytics);
    on<LoadActivity>(_onLoadActivity);
    on<LoadEvents>(_onLoadEvents);
    on<CreateEvent>(_onCreateEvent);
    on<UpdateEvent>(_onUpdateEvent);
    on<CancelEvent>(_onCancelEvent);
    on<DuplicateEvent>(_onDuplicateEvent);
    on<LoadAttendees>(_onLoadAttendees);
    on<MarkAttendance>(_onMarkAttendance);
    on<RemoveAttendee>(_onRemoveAttendee);
    on<LoadProfile>(_onLoadProfile);
    on<UpdateProfile>(_onUpdateProfile);
    on<LoadMembers>(_onLoadMembers);
    on<AddMember>(_onAddMember);
    on<UpdateMemberRole>(_onUpdateMemberRole);
    on<RemoveMember>(_onRemoveMember);
  }

  Future<void> _onLoadDashboard(LoadDashboard event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final res = await datasource.getDashboard(orgId);
      emit(state.copyWith(isLoading: false, dashboardStats: res['data'] as Map<String, dynamic>?));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadAnalytics(LoadAnalytics event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final res = await datasource.getAnalytics(orgId);
      emit(state.copyWith(isLoading: false, analyticsData: res['data'] as Map<String, dynamic>?));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadActivity(LoadActivity event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final res = await datasource.getActivity(orgId);
      emit(state.copyWith(isLoading: false, activityLog: res['data'] as List<dynamic>?));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadEvents(LoadEvents event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final res = await datasource.listEvents(orgId, page: event.page, status: event.statusFilter);
      emit(state.copyWith(
        isLoading: false,
        events: res['data'] as List<dynamic>?,
        eventsTotalCount: (res['total_count'] as num?)?.toInt() ?? 0,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onCreateEvent(CreateEvent event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await datasource.createEvent(orgId, event.data);
      emit(state.copyWith(isLoading: false, successMessage: 'Event created'));
      add(LoadEvents());
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onUpdateEvent(UpdateEvent event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await datasource.updateEvent(orgId, event.eventId, event.data);
      emit(state.copyWith(isLoading: false, successMessage: 'Event updated'));
      add(LoadEvents());
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onCancelEvent(CancelEvent event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await datasource.cancelEvent(orgId, event.eventId);
      emit(state.copyWith(isLoading: false, successMessage: 'Event cancelled'));
      add(LoadEvents());
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onDuplicateEvent(DuplicateEvent event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await datasource.duplicateEvent(orgId, event.eventId);
      emit(state.copyWith(isLoading: false, successMessage: 'Event duplicated'));
      add(LoadEvents());
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadAttendees(LoadAttendees event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final res = await datasource.listAttendees(
        orgId, event.eventId,
        page: event.page, search: event.search, status: event.statusFilter,
      );
      emit(state.copyWith(
        isLoading: false,
        attendees: res['data'] as List<dynamic>?,
        attendeesTotalCount: (res['total_count'] as num?)?.toInt() ?? 0,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onMarkAttendance(MarkAttendance event, Emitter<OrgDashState> emit) async {
    try {
      await datasource.markAttendance(orgId, event.eventId, event.regId, event.attended);
      emit(state.copyWith(successMessage: event.attended ? 'Marked present' : 'Marked absent'));
      add(LoadAttendees(event.eventId));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRemoveAttendee(RemoveAttendee event, Emitter<OrgDashState> emit) async {
    try {
      await datasource.removeAttendee(orgId, event.eventId, event.regId);
      emit(state.copyWith(successMessage: 'Attendee removed'));
      add(LoadAttendees(event.eventId));
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onLoadProfile(LoadProfile event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final res = await datasource.getProfile(orgId);
      emit(state.copyWith(isLoading: false, profile: res['data'] as Map<String, dynamic>?));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onUpdateProfile(UpdateProfile event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final res = await datasource.updateProfile(orgId, event.data);
      emit(state.copyWith(
        isLoading: false,
        profile: res['data'] as Map<String, dynamic>?,
        successMessage: 'Profile updated',
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onLoadMembers(LoadMembers event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final res = await datasource.listMembers(orgId);
      emit(state.copyWith(isLoading: false, members: res['data'] as List<dynamic>?));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onAddMember(AddMember event, Emitter<OrgDashState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      await datasource.addMember(orgId, event.email, event.role);
      emit(state.copyWith(isLoading: false, successMessage: 'Member added'));
      add(LoadMembers());
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onUpdateMemberRole(UpdateMemberRole event, Emitter<OrgDashState> emit) async {
    try {
      await datasource.updateMemberRole(orgId, event.memberId, event.role);
      emit(state.copyWith(successMessage: 'Role updated'));
      add(LoadMembers());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  Future<void> _onRemoveMember(RemoveMember event, Emitter<OrgDashState> emit) async {
    try {
      await datasource.removeMember(orgId, event.memberId);
      emit(state.copyWith(successMessage: 'Member removed'));
      add(LoadMembers());
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }
}
