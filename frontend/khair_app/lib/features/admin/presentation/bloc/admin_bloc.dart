import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../organizer/domain/entities/organizer.dart';
import '../../../events/domain/entities/event.dart';
import '../../domain/entities/admin_entities.dart';
import '../../domain/repositories/admin_repository.dart';

part 'admin_event.dart';
part 'admin_state.dart';

/// BLoC for managing admin panel state
class AdminBloc extends Bloc<AdminEvent, AdminState> {
  final AdminRepository _adminRepository;

  AdminBloc(this._adminRepository) : super(const AdminState()) {
    on<LoadAdminData>(_onLoadData);
    on<LoadPendingOrganizers>(_onLoadPendingOrganizers);
    on<LoadPendingEvents>(_onLoadPendingEvents);
    on<LoadPendingReports>(_onLoadPendingReports);
    on<ApproveOrganizer>(_onApproveOrganizer);
    on<RejectOrganizer>(_onRejectOrganizer);
    on<ApproveEvent>(_onApproveEvent);
    on<RejectEvent>(_onRejectEvent);
    on<ResolveReport>(_onResolveReport);
  }

  Future<void> _onLoadData(
    LoadAdminData event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(status: AdminStatus.loading));

    // Load all pending data in parallel
    final results = await Future.wait([
      _adminRepository.getPendingOrganizers(),
      _adminRepository.getPendingEvents(),
      _adminRepository.getPendingReports(),
    ]);

    final organizersResult = results[0];
    final eventsResult = results[1];
    final reportsResult = results[2];

    List<Organizer> organizers = [];
    List<Event> events = [];
    List<Report> reports = [];
    String? error;

    organizersResult.fold(
      (failure) => error = failure.message,
      (data) => organizers = data as List<Organizer>,
    );

    eventsResult.fold(
      (failure) => error ??= failure.message,
      (data) => events = data as List<Event>,
    );

    reportsResult.fold(
      (failure) => error ??= failure.message,
      (data) => reports = data as List<Report>,
    );

    if (error != null) {
      emit(state.copyWith(
        status: AdminStatus.failure,
        errorMessage: error,
      ));
    } else {
      emit(state.copyWith(
        status: AdminStatus.success,
        pendingOrganizers: organizers,
        pendingEvents: events,
        pendingReports: reports,
      ));
    }
  }

  Future<void> _onLoadPendingOrganizers(
    LoadPendingOrganizers event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(organizersStatus: AdminStatus.loading));

    final result = await _adminRepository.getPendingOrganizers();

    result.fold(
      (failure) => emit(state.copyWith(
        organizersStatus: AdminStatus.failure,
        errorMessage: failure.message,
      )),
      (organizers) => emit(state.copyWith(
        organizersStatus: AdminStatus.success,
        pendingOrganizers: organizers,
      )),
    );
  }

  Future<void> _onLoadPendingEvents(
    LoadPendingEvents event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(eventsStatus: AdminStatus.loading));

    final result = await _adminRepository.getPendingEvents();

    result.fold(
      (failure) => emit(state.copyWith(
        eventsStatus: AdminStatus.failure,
        errorMessage: failure.message,
      )),
      (events) => emit(state.copyWith(
        eventsStatus: AdminStatus.success,
        pendingEvents: events,
      )),
    );
  }

  Future<void> _onLoadPendingReports(
    LoadPendingReports event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(reportsStatus: AdminStatus.loading));

    final result = await _adminRepository.getPendingReports();

    result.fold(
      (failure) => emit(state.copyWith(
        reportsStatus: AdminStatus.failure,
        errorMessage: failure.message,
      )),
      (reports) => emit(state.copyWith(
        reportsStatus: AdminStatus.success,
        pendingReports: reports,
      )),
    );
  }

  Future<void> _onApproveOrganizer(
    ApproveOrganizer event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(actionStatus: AdminStatus.loading));

    final result = await _adminRepository.updateOrganizerStatus(
      event.organizerId,
      const StatusUpdateParams(status: 'approved'),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        actionStatus: AdminStatus.failure,
        errorMessage: failure.message,
      )),
      (organizer) {
        // Remove from pending list
        final updated = state.pendingOrganizers
            .where((o) => o.id != event.organizerId)
            .toList();
        emit(state.copyWith(
          actionStatus: AdminStatus.success,
          pendingOrganizers: updated,
        ));
      },
    );
  }

  Future<void> _onRejectOrganizer(
    RejectOrganizer event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(actionStatus: AdminStatus.loading));

    final result = await _adminRepository.updateOrganizerStatus(
      event.organizerId,
      StatusUpdateParams(status: 'rejected', reason: event.reason),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        actionStatus: AdminStatus.failure,
        errorMessage: failure.message,
      )),
      (organizer) {
        final updated = state.pendingOrganizers
            .where((o) => o.id != event.organizerId)
            .toList();
        emit(state.copyWith(
          actionStatus: AdminStatus.success,
          pendingOrganizers: updated,
        ));
      },
    );
  }

  Future<void> _onApproveEvent(
    ApproveEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(actionStatus: AdminStatus.loading));

    final result = await _adminRepository.updateEventStatus(
      event.eventId,
      const StatusUpdateParams(status: 'approved'),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        actionStatus: AdminStatus.failure,
        errorMessage: failure.message,
      )),
      (updatedEvent) {
        final updated = state.pendingEvents
            .where((e) => e.id != event.eventId)
            .toList();
        emit(state.copyWith(
          actionStatus: AdminStatus.success,
          pendingEvents: updated,
        ));
      },
    );
  }

  Future<void> _onRejectEvent(
    RejectEvent event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(actionStatus: AdminStatus.loading));

    final result = await _adminRepository.updateEventStatus(
      event.eventId,
      StatusUpdateParams(status: 'rejected', reason: event.reason),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        actionStatus: AdminStatus.failure,
        errorMessage: failure.message,
      )),
      (updatedEvent) {
        final updated = state.pendingEvents
            .where((e) => e.id != event.eventId)
            .toList();
        emit(state.copyWith(
          actionStatus: AdminStatus.success,
          pendingEvents: updated,
        ));
      },
    );
  }

  Future<void> _onResolveReport(
    ResolveReport event,
    Emitter<AdminState> emit,
  ) async {
    emit(state.copyWith(actionStatus: AdminStatus.loading));

    final result = await _adminRepository.resolveReport(
      event.reportId,
      ReportResolutionParams(
        resolution: event.resolution,
        action: event.action,
      ),
    );

    result.fold(
      (failure) => emit(state.copyWith(
        actionStatus: AdminStatus.failure,
        errorMessage: failure.message,
      )),
      (report) {
        final updated = state.pendingReports
            .where((r) => r.id != event.reportId)
            .toList();
        emit(state.copyWith(
          actionStatus: AdminStatus.success,
          pendingReports: updated,
        ));
      },
    );
  }
}
