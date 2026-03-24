import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../chat/domain/entities/lesson_request.dart';
import '../../data/sheikh_dashboard_datasource.dart';

// ─── Events ────────────────────────────────────────

abstract class SheikhDashboardEvent extends Equatable {
  const SheikhDashboardEvent();
  @override
  List<Object?> get props => [];
}

class LoadLessonRequests extends SheikhDashboardEvent {
  const LoadLessonRequests();
}

class RespondToRequest extends SheikhDashboardEvent {
  final String requestId;
  final String status; // 'accepted' or 'rejected'

  const RespondToRequest({required this.requestId, required this.status});

  @override
  List<Object?> get props => [requestId, status];
}

class ScheduleLesson extends SheikhDashboardEvent {
  final String requestId;
  final String meetingLink;
  final String meetingPlatform;
  final String scheduledTime;

  const ScheduleLesson({
    required this.requestId,
    required this.meetingLink,
    required this.meetingPlatform,
    required this.scheduledTime,
  });

  @override
  List<Object?> get props => [requestId, meetingLink, meetingPlatform, scheduledTime];
}

// ─── State ─────────────────────────────────────────

enum SheikhDashboardStatus { initial, loading, success, failure }

class SheikhDashboardState extends Equatable {
  final SheikhDashboardStatus status;
  final List<LessonRequest> requests;
  final String? errorMessage;
  final String? actionMessage; // success message for accept/reject

  const SheikhDashboardState({
    this.status = SheikhDashboardStatus.initial,
    this.requests = const [],
    this.errorMessage,
    this.actionMessage,
  });

  List<LessonRequest> get pendingRequests =>
      requests.where((r) => r.isPending).toList();

  List<LessonRequest> get acceptedRequests =>
      requests.where((r) => r.isAccepted).toList();

  List<LessonRequest> get rejectedRequests =>
      requests.where((r) => r.isRejected).toList();

  SheikhDashboardState copyWith({
    SheikhDashboardStatus? status,
    List<LessonRequest>? requests,
    String? errorMessage,
    String? actionMessage,
  }) {
    return SheikhDashboardState(
      status: status ?? this.status,
      requests: requests ?? this.requests,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [status, requests, errorMessage, actionMessage];
}

// ─── Bloc ──────────────────────────────────────────

class SheikhDashboardBloc extends Bloc<SheikhDashboardEvent, SheikhDashboardState> {
  final SheikhDashboardDatasource _datasource;

  SheikhDashboardBloc(this._datasource) : super(const SheikhDashboardState()) {
    on<LoadLessonRequests>(_onLoadRequests);
    on<RespondToRequest>(_onRespond);
    on<ScheduleLesson>(_onSchedule);
  }

  Future<void> _onLoadRequests(
    LoadLessonRequests event,
    Emitter<SheikhDashboardState> emit,
  ) async {
    emit(state.copyWith(status: SheikhDashboardStatus.loading));
    try {
      final requests = await _datasource.getLessonRequests();
      emit(state.copyWith(
        status: SheikhDashboardStatus.success,
        requests: requests,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: SheikhDashboardStatus.failure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRespond(
    RespondToRequest event,
    Emitter<SheikhDashboardState> emit,
  ) async {
    try {
      final updated = await _datasource.respondToRequest(event.requestId, event.status);
      final newRequests = state.requests.map((r) {
        return r.id == event.requestId ? updated : r;
      }).toList();
      final action = event.status == 'accepted' ? 'accepted' : 'declined';
      emit(state.copyWith(
        requests: newRequests,
        actionMessage: 'Request $action successfully',
      ));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to respond: $e'));
    }
  }

  Future<void> _onSchedule(
    ScheduleLesson event,
    Emitter<SheikhDashboardState> emit,
  ) async {
    try {
      await _datasource.scheduleLesson(
        requestId: event.requestId,
        meetingLink: event.meetingLink,
        meetingPlatform: event.meetingPlatform,
        scheduledTime: event.scheduledTime,
      );
      emit(state.copyWith(actionMessage: 'Lesson scheduled successfully'));
      add(const LoadLessonRequests()); // refresh
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to schedule: $e'));
    }
  }
}
