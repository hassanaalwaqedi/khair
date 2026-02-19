import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/organizer.dart';
import '../../domain/repositories/organizer_repository.dart';
import '../../../events/domain/entities/event.dart';

part 'organizer_event.dart';
part 'organizer_state.dart';

/// BLoC for managing organizer state
class OrganizerBloc extends Bloc<OrganizerEvent, OrganizerState> {
  final OrganizerRepository _organizerRepository;

  OrganizerBloc(this._organizerRepository) : super(const OrganizerState()) {
    on<LoadOrganizerProfile>(_onLoadProfile);
    on<LoadOrganizerEvents>(_onLoadEvents);
    on<LoadAdminMessages>(_onLoadMessages);
    on<ApplyAsOrganizer>(_onApply);
    on<UpdateOrganizerProfile>(_onUpdateProfile);
    on<MarkMessageRead>(_onMarkMessageRead);
  }

  Future<void> _onLoadProfile(
    LoadOrganizerProfile event,
    Emitter<OrganizerState> emit,
  ) async {
    emit(state.copyWith(profileStatus: OrganizerStatus.loading));

    final result = await _organizerRepository.getMyProfile();

    result.fold(
      (failure) => emit(state.copyWith(
        profileStatus: OrganizerStatus.failure,
        errorMessage: failure.message,
      )),
      (organizer) => emit(state.copyWith(
        profileStatus: OrganizerStatus.success,
        organizer: organizer,
      )),
    );
  }

  Future<void> _onLoadEvents(
    LoadOrganizerEvents event,
    Emitter<OrganizerState> emit,
  ) async {
    emit(state.copyWith(eventsStatus: OrganizerStatus.loading));

    final result = await _organizerRepository.getMyEvents();

    result.fold(
      (failure) => emit(state.copyWith(
        eventsStatus: OrganizerStatus.failure,
        errorMessage: failure.message,
      )),
      (events) => emit(state.copyWith(
        eventsStatus: OrganizerStatus.success,
        events: events,
      )),
    );
  }

  Future<void> _onLoadMessages(
    LoadAdminMessages event,
    Emitter<OrganizerState> emit,
  ) async {
    emit(state.copyWith(messagesStatus: OrganizerStatus.loading));

    final result = await _organizerRepository.getAdminMessages();

    result.fold(
      (failure) => emit(state.copyWith(
        messagesStatus: OrganizerStatus.failure,
        errorMessage: failure.message,
      )),
      (messages) => emit(state.copyWith(
        messagesStatus: OrganizerStatus.success,
        messages: messages,
      )),
    );
  }

  Future<void> _onApply(
    ApplyAsOrganizer event,
    Emitter<OrganizerState> emit,
  ) async {
    emit(state.copyWith(applicationStatus: OrganizerStatus.loading));

    final result = await _organizerRepository.applyAsOrganizer(event.params);

    result.fold(
      (failure) => emit(state.copyWith(
        applicationStatus: OrganizerStatus.failure,
        errorMessage: failure.message,
      )),
      (organizer) => emit(state.copyWith(
        applicationStatus: OrganizerStatus.success,
        organizer: organizer,
      )),
    );
  }

  Future<void> _onUpdateProfile(
    UpdateOrganizerProfile event,
    Emitter<OrganizerState> emit,
  ) async {
    emit(state.copyWith(profileStatus: OrganizerStatus.loading));

    final result = await _organizerRepository.updateProfile(event.params);

    result.fold(
      (failure) => emit(state.copyWith(
        profileStatus: OrganizerStatus.failure,
        errorMessage: failure.message,
      )),
      (organizer) => emit(state.copyWith(
        profileStatus: OrganizerStatus.success,
        organizer: organizer,
      )),
    );
  }

  Future<void> _onMarkMessageRead(
    MarkMessageRead event,
    Emitter<OrganizerState> emit,
  ) async {
    final result = await _organizerRepository.markMessageAsRead(event.messageId);

    result.fold(
      (failure) => null, // Silently fail
      (_) {
        // Update local state to mark message as read
        final updatedMessages = state.messages.map((m) {
          if (m.id == event.messageId) {
            return AdminMessage(
              id: m.id,
              organizerId: m.organizerId,
              subject: m.subject,
              message: m.message,
              isRead: true,
              createdAt: m.createdAt,
            );
          }
          return m;
        }).toList();
        emit(state.copyWith(messages: updatedMessages));
      },
    );
  }
}
