import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/datasources/join_datasource.dart';

// ── Events ──

abstract class JoinEvent extends Equatable {
  const JoinEvent();
  @override
  List<Object?> get props => [];
}

class SubmitJoinStep1 extends JoinEvent {
  final String name;
  final String email;
  final String? eventId;
  const SubmitJoinStep1({required this.name, required this.email, this.eventId});
  @override
  List<Object?> get props => [name, email, eventId];
}

class SubmitJoinStep2 extends JoinEvent {
  final String password;
  final String gender;
  final int? age;
  const SubmitJoinStep2({required this.password, required this.gender, this.age});
  @override
  List<Object?> get props => [password, gender, age];
}

class ReserveSeat extends JoinEvent {
  final String eventId;
  const ReserveSeat(this.eventId);
  @override
  List<Object?> get props => [eventId];
}

class CheckAvailability extends JoinEvent {
  final String eventId;
  const CheckAvailability(this.eventId);
  @override
  List<Object?> get props => [eventId];
}

class ResetJoinFlow extends JoinEvent {
  const ResetJoinFlow();
}

// ── State ──

enum JoinStatus { initial, loading, step1Complete, step2Complete, seatReserved, failure }

class JoinState extends Equatable {
  final JoinStatus status;
  final int currentStep;
  final String? draftId;
  final String? userId;
  final String? errorMessage;
  final String? eventId;
  final bool seatReserved;
  final String? reservedUntil;
  final int? capacity;
  final int? remaining;
  final bool available;

  // In-memory draft data
  final String? savedName;
  final String? savedEmail;

  const JoinState({
    this.status = JoinStatus.initial,
    this.currentStep = 1,
    this.draftId,
    this.userId,
    this.errorMessage,
    this.eventId,
    this.seatReserved = false,
    this.reservedUntil,
    this.capacity,
    this.remaining,
    this.available = true,
    this.savedName,
    this.savedEmail,
  });

  JoinState copyWith({
    JoinStatus? status,
    int? currentStep,
    String? draftId,
    String? userId,
    String? errorMessage,
    String? eventId,
    bool? seatReserved,
    String? reservedUntil,
    int? capacity,
    int? remaining,
    bool? available,
    String? savedName,
    String? savedEmail,
  }) {
    return JoinState(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      draftId: draftId ?? this.draftId,
      userId: userId ?? this.userId,
      errorMessage: errorMessage ?? this.errorMessage,
      eventId: eventId ?? this.eventId,
      seatReserved: seatReserved ?? this.seatReserved,
      reservedUntil: reservedUntil ?? this.reservedUntil,
      capacity: capacity ?? this.capacity,
      remaining: remaining ?? this.remaining,
      available: available ?? this.available,
      savedName: savedName ?? this.savedName,
      savedEmail: savedEmail ?? this.savedEmail,
    );
  }

  @override
  List<Object?> get props => [
        status, currentStep, draftId, userId, errorMessage, eventId,
        seatReserved, reservedUntil, capacity, remaining, available,
        savedName, savedEmail,
      ];
}

// ── BLoC ──

class JoinBloc extends Bloc<JoinEvent, JoinState> {
  final JoinDataSource _dataSource;

  JoinBloc(this._dataSource) : super(const JoinState()) {
    on<SubmitJoinStep1>(_onStep1);
    on<SubmitJoinStep2>(_onStep2);
    on<ReserveSeat>(_onReserveSeat);
    on<CheckAvailability>(_onCheckAvailability);
    on<ResetJoinFlow>(_onReset);
  }

  Future<void> _onStep1(SubmitJoinStep1 event, Emitter<JoinState> emit) async {
    emit(state.copyWith(status: JoinStatus.loading));
    try {
      final result = await _dataSource.submitStep1(
        name: event.name,
        email: event.email,
        eventId: event.eventId,
      );
      emit(state.copyWith(
        status: JoinStatus.step1Complete,
        currentStep: 2,
        draftId: result['draft_id'] as String?,
        eventId: event.eventId,
        savedName: event.name,
        savedEmail: event.email,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: JoinStatus.failure,
        errorMessage: _extractError(e),
      ));
    }
  }

  Future<void> _onStep2(SubmitJoinStep2 event, Emitter<JoinState> emit) async {
    emit(state.copyWith(status: JoinStatus.loading));
    try {
      final result = await _dataSource.submitStep2(
        draftId: state.draftId!,
        password: event.password,
        gender: event.gender,
        age: event.age,
      );
      emit(state.copyWith(
        status: JoinStatus.step2Complete,
        userId: result['user_id'] as String?,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: JoinStatus.failure,
        errorMessage: _extractError(e),
      ));
    }
  }

  Future<void> _onReserveSeat(ReserveSeat event, Emitter<JoinState> emit) async {
    emit(state.copyWith(status: JoinStatus.loading));
    try {
      final result = await _dataSource.joinEvent(event.eventId);
      emit(state.copyWith(
        status: JoinStatus.seatReserved,
        seatReserved: true,
        reservedUntil: result['reserved_until']?.toString(),
      ));
    } catch (e) {
      emit(state.copyWith(
        status: JoinStatus.failure,
        errorMessage: _extractError(e),
      ));
    }
  }

  Future<void> _onCheckAvailability(CheckAvailability event, Emitter<JoinState> emit) async {
    try {
      final result = await _dataSource.getAvailability(event.eventId);
      emit(state.copyWith(
        capacity: result['capacity'] as int?,
        remaining: result['remaining'] as int?,
        available: result['available'] as bool? ?? true,
      ));
    } catch (_) {
      // Non-critical, keep going
    }
  }

  void _onReset(ResetJoinFlow event, Emitter<JoinState> emit) {
    emit(const JoinState());
  }

  String _extractError(dynamic e) {
    if (e is Exception) {
      return e.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }
}
