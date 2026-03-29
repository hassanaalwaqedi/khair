import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/booking_datasource.dart';

// ══════════════════════════════════════════
//  EVENTS
// ══════════════════════════════════════════

abstract class BookingEvent extends Equatable {
  const BookingEvent();
  @override
  List<Object?> get props => [];
}

/// Load available slots for a sheikh on a date
class LoadAvailableSlots extends BookingEvent {
  final String sheikhId;
  final String date; // YYYY-MM-DD
  const LoadAvailableSlots(this.sheikhId, this.date);
  @override
  List<Object?> get props => [sheikhId, date];
}

/// Select a time slot
class SelectSlot extends BookingEvent {
  final Map<String, dynamic> slot;
  const SelectSlot(this.slot);
  @override
  List<Object?> get props => [slot];
}

/// Create a booking
class CreateBooking extends BookingEvent {
  final String sheikhId;
  final String startTime;
  final int duration;
  final String? notes;
  const CreateBooking({
    required this.sheikhId,
    required this.startTime,
    this.duration = 30,
    this.notes,
  });
  @override
  List<Object?> get props => [sheikhId, startTime, duration, notes];
}

/// Load student's bookings
class LoadMyBookings extends BookingEvent {
  const LoadMyBookings();
}

/// Cancel a booking
class CancelBooking extends BookingEvent {
  final String bookingId;
  const CancelBooking(this.bookingId);
  @override
  List<Object?> get props => [bookingId];
}

/// Load sheikh availability rules
class LoadSheikhAvailability extends BookingEvent {
  final String sheikhId;
  const LoadSheikhAvailability(this.sheikhId);
  @override
  List<Object?> get props => [sheikhId];
}

/// Save sheikh availability rules
class SaveAvailability extends BookingEvent {
  final List<Map<String, dynamic>> rules;
  const SaveAvailability(this.rules);
  @override
  List<Object?> get props => [rules];
}

/// Load booking settings
class LoadBookingSettings extends BookingEvent {
  const LoadBookingSettings();
}

/// Update booking settings
class UpdateBookingSettings extends BookingEvent {
  final Map<String, dynamic> settings;
  const UpdateBookingSettings(this.settings);
  @override
  List<Object?> get props => [settings];
}

/// Load sheikh's bookings
class LoadSheikhBookings extends BookingEvent {
  const LoadSheikhBookings();
}

/// Respond to a booking (accept/reject)
class RespondToBooking extends BookingEvent {
  final String bookingId;
  final String status;
  const RespondToBooking(this.bookingId, this.status);
  @override
  List<Object?> get props => [bookingId, status];
}

// ══════════════════════════════════════════
//  STATE
// ══════════════════════════════════════════

enum BookingStatus { initial, loading, success, failure }

class BookingState extends Equatable {
  final BookingStatus slotsStatus;
  final BookingStatus bookingStatus;
  final BookingStatus settingsStatus;
  final List<Map<String, dynamic>> availableSlots;
  final Map<String, dynamic>? selectedSlot;
  final List<Map<String, dynamic>> myBookings;
  final List<Map<String, dynamic>> sheikhBookings;
  final List<Map<String, dynamic>> availabilityRules;
  final Map<String, dynamic>? bookingSettings;
  final Map<String, dynamic>? createdBooking;
  final String? errorMessage;
  final String? selectedDate;

  const BookingState({
    this.slotsStatus = BookingStatus.initial,
    this.bookingStatus = BookingStatus.initial,
    this.settingsStatus = BookingStatus.initial,
    this.availableSlots = const [],
    this.selectedSlot,
    this.myBookings = const [],
    this.sheikhBookings = const [],
    this.availabilityRules = const [],
    this.bookingSettings,
    this.createdBooking,
    this.errorMessage,
    this.selectedDate,
  });

  BookingState copyWith({
    BookingStatus? slotsStatus,
    BookingStatus? bookingStatus,
    BookingStatus? settingsStatus,
    List<Map<String, dynamic>>? availableSlots,
    Map<String, dynamic>? selectedSlot,
    List<Map<String, dynamic>>? myBookings,
    List<Map<String, dynamic>>? sheikhBookings,
    List<Map<String, dynamic>>? availabilityRules,
    Map<String, dynamic>? bookingSettings,
    Map<String, dynamic>? createdBooking,
    String? errorMessage,
    String? selectedDate,
    bool clearSelectedSlot = false,
    bool clearCreatedBooking = false,
  }) {
    return BookingState(
      slotsStatus: slotsStatus ?? this.slotsStatus,
      bookingStatus: bookingStatus ?? this.bookingStatus,
      settingsStatus: settingsStatus ?? this.settingsStatus,
      availableSlots: availableSlots ?? this.availableSlots,
      selectedSlot: clearSelectedSlot ? null : (selectedSlot ?? this.selectedSlot),
      myBookings: myBookings ?? this.myBookings,
      sheikhBookings: sheikhBookings ?? this.sheikhBookings,
      availabilityRules: availabilityRules ?? this.availabilityRules,
      bookingSettings: bookingSettings ?? this.bookingSettings,
      createdBooking: clearCreatedBooking ? null : (createdBooking ?? this.createdBooking),
      errorMessage: errorMessage,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  @override
  List<Object?> get props => [
    slotsStatus, bookingStatus, settingsStatus,
    availableSlots, selectedSlot, myBookings, sheikhBookings,
    availabilityRules, bookingSettings, createdBooking,
    errorMessage, selectedDate,
  ];
}

// ══════════════════════════════════════════
//  BLOC
// ══════════════════════════════════════════

class BookingBloc extends Bloc<BookingEvent, BookingState> {
  final BookingDatasource _datasource;

  BookingBloc(this._datasource) : super(const BookingState()) {
    on<LoadAvailableSlots>(_onLoadSlots);
    on<SelectSlot>(_onSelectSlot);
    on<CreateBooking>(_onCreateBooking);
    on<LoadMyBookings>(_onLoadMyBookings);
    on<CancelBooking>(_onCancelBooking);
    on<LoadSheikhAvailability>(_onLoadAvailability);
    on<SaveAvailability>(_onSaveAvailability);
    on<LoadBookingSettings>(_onLoadSettings);
    on<UpdateBookingSettings>(_onUpdateSettings);
    on<LoadSheikhBookings>(_onLoadSheikhBookings);
    on<RespondToBooking>(_onRespondToBooking);
  }

  Future<void> _onLoadSlots(LoadAvailableSlots event, Emitter<BookingState> emit) async {
    emit(state.copyWith(slotsStatus: BookingStatus.loading, selectedDate: event.date, clearSelectedSlot: true));
    try {
      final slots = await _datasource.getAvailableSlots(event.sheikhId, event.date);
      emit(state.copyWith(slotsStatus: BookingStatus.success, availableSlots: slots));
    } catch (e) {
      emit(state.copyWith(slotsStatus: BookingStatus.failure, errorMessage: e.toString()));
    }
  }

  void _onSelectSlot(SelectSlot event, Emitter<BookingState> emit) {
    emit(state.copyWith(selectedSlot: event.slot));
  }

  Future<void> _onCreateBooking(CreateBooking event, Emitter<BookingState> emit) async {
    emit(state.copyWith(bookingStatus: BookingStatus.loading));
    try {
      final booking = await _datasource.createBooking(
        sheikhId: event.sheikhId,
        startTime: event.startTime,
        duration: event.duration,
        notes: event.notes,
      );
      emit(state.copyWith(bookingStatus: BookingStatus.success, createdBooking: booking));
    } catch (e) {
      emit(state.copyWith(bookingStatus: BookingStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadMyBookings(LoadMyBookings event, Emitter<BookingState> emit) async {
    emit(state.copyWith(bookingStatus: BookingStatus.loading));
    try {
      final bookings = await _datasource.getMyBookings();
      emit(state.copyWith(bookingStatus: BookingStatus.success, myBookings: bookings));
    } catch (e) {
      emit(state.copyWith(bookingStatus: BookingStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onCancelBooking(CancelBooking event, Emitter<BookingState> emit) async {
    try {
      await _datasource.cancelBooking(event.bookingId);
      add(const LoadMyBookings());
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadAvailability(LoadSheikhAvailability event, Emitter<BookingState> emit) async {
    emit(state.copyWith(settingsStatus: BookingStatus.loading));
    try {
      final rules = await _datasource.getAvailability(event.sheikhId);
      emit(state.copyWith(settingsStatus: BookingStatus.success, availabilityRules: rules));
    } catch (e) {
      emit(state.copyWith(settingsStatus: BookingStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onSaveAvailability(SaveAvailability event, Emitter<BookingState> emit) async {
    emit(state.copyWith(settingsStatus: BookingStatus.loading));
    try {
      await _datasource.setAvailability(event.rules);
      emit(state.copyWith(settingsStatus: BookingStatus.success));
    } catch (e) {
      emit(state.copyWith(settingsStatus: BookingStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadSettings(LoadBookingSettings event, Emitter<BookingState> emit) async {
    emit(state.copyWith(settingsStatus: BookingStatus.loading));
    try {
      final settings = await _datasource.getBookingSettings();
      emit(state.copyWith(settingsStatus: BookingStatus.success, bookingSettings: settings));
    } catch (e) {
      emit(state.copyWith(settingsStatus: BookingStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdateSettings(UpdateBookingSettings event, Emitter<BookingState> emit) async {
    emit(state.copyWith(settingsStatus: BookingStatus.loading));
    try {
      await _datasource.updateBookingSettings(event.settings);
      emit(state.copyWith(settingsStatus: BookingStatus.success, bookingSettings: event.settings));
    } catch (e) {
      emit(state.copyWith(settingsStatus: BookingStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onLoadSheikhBookings(LoadSheikhBookings event, Emitter<BookingState> emit) async {
    emit(state.copyWith(bookingStatus: BookingStatus.loading));
    try {
      final bookings = await _datasource.getSheikhBookings();
      emit(state.copyWith(bookingStatus: BookingStatus.success, sheikhBookings: bookings));
    } catch (e) {
      emit(state.copyWith(bookingStatus: BookingStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> _onRespondToBooking(RespondToBooking event, Emitter<BookingState> emit) async {
    try {
      await _datasource.respondToBooking(event.bookingId, event.status);
      add(const LoadSheikhBookings());
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
