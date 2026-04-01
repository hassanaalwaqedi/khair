import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/student_dashboard_datasource.dart';

// ══════════════════════════════════════════
//  EVENTS
// ══════════════════════════════════════════

abstract class StudentDashboardEvent extends Equatable {
  const StudentDashboardEvent();
  @override
  List<Object?> get props => [];
}

/// Load all dashboard data at once.
class LoadDashboard extends StudentDashboardEvent {
  const LoadDashboard();
}

/// Change the active tab index.
class ChangeTab extends StudentDashboardEvent {
  final int tabIndex;
  const ChangeTab(this.tabIndex);
  @override
  List<Object?> get props => [tabIndex];
}

/// Cancel a booking.
class CancelStudentBooking extends StudentDashboardEvent {
  final String bookingId;
  const CancelStudentBooking(this.bookingId);
  @override
  List<Object?> get props => [bookingId];
}

/// Submit a review for a sheikh.
class SubmitSheikhReview extends StudentDashboardEvent {
  final String sheikhId;
  final int rating;
  final String? comment;
  final String? lessonRequestId;
  const SubmitSheikhReview({
    required this.sheikhId,
    required this.rating,
    this.comment,
    this.lessonRequestId,
  });
  @override
  List<Object?> get props => [sheikhId, rating, comment, lessonRequestId];
}

// ══════════════════════════════════════════
//  STATE
// ══════════════════════════════════════════

enum DashboardStatus { initial, loading, loaded, error }

class StudentDashboardState extends Equatable {
  final DashboardStatus status;
  final int selectedTab;
  final List<Map<String, dynamic>> upcomingLessons;
  final List<Map<String, dynamic>> pastLessons;
  final List<Map<String, dynamic>> lessonRequests;
  final List<Map<String, dynamic>> mySheikhs;
  final Map<String, dynamic> stats;
  final String? errorMessage;
  final String? reviewMessage;

  const StudentDashboardState({
    this.status = DashboardStatus.initial,
    this.selectedTab = 0,
    this.upcomingLessons = const [],
    this.pastLessons = const [],
    this.lessonRequests = const [],
    this.mySheikhs = const [],
    this.stats = const {},
    this.errorMessage,
    this.reviewMessage,
  });

  StudentDashboardState copyWith({
    DashboardStatus? status,
    int? selectedTab,
    List<Map<String, dynamic>>? upcomingLessons,
    List<Map<String, dynamic>>? pastLessons,
    List<Map<String, dynamic>>? lessonRequests,
    List<Map<String, dynamic>>? mySheikhs,
    Map<String, dynamic>? stats,
    String? errorMessage,
    String? reviewMessage,
    bool clearReviewMessage = false,
  }) {
    return StudentDashboardState(
      status: status ?? this.status,
      selectedTab: selectedTab ?? this.selectedTab,
      upcomingLessons: upcomingLessons ?? this.upcomingLessons,
      pastLessons: pastLessons ?? this.pastLessons,
      lessonRequests: lessonRequests ?? this.lessonRequests,
      mySheikhs: mySheikhs ?? this.mySheikhs,
      stats: stats ?? this.stats,
      errorMessage: errorMessage,
      reviewMessage: clearReviewMessage ? null : (reviewMessage ?? this.reviewMessage),
    );
  }

  @override
  List<Object?> get props => [
        status, selectedTab, upcomingLessons, pastLessons,
        lessonRequests, mySheikhs, stats, errorMessage, reviewMessage,
      ];
}

// ══════════════════════════════════════════
//  BLOC
// ══════════════════════════════════════════

class StudentDashboardBloc
    extends Bloc<StudentDashboardEvent, StudentDashboardState> {
  final StudentDashboardDatasource _datasource;

  StudentDashboardBloc(this._datasource)
      : super(const StudentDashboardState()) {
    on<LoadDashboard>(_onLoad);
    on<ChangeTab>(_onChangeTab);
    on<CancelStudentBooking>(_onCancelBooking);
    on<SubmitSheikhReview>(_onSubmitReview);
  }

  Future<void> _onLoad(
      LoadDashboard event, Emitter<StudentDashboardState> emit) async {
    emit(state.copyWith(status: DashboardStatus.loading));
    try {
      final results = await Future.wait([
        _datasource.getMyBookings(),
        _datasource.getMyLessonRequests(),
        _datasource.getMySheikhs(),
        _datasource.getMyStats(),
      ]);

      final allBookings = results[0] as List<Map<String, dynamic>>;
      final requests = results[1] as List<Map<String, dynamic>>;
      final sheikhs = results[2] as List<Map<String, dynamic>>;
      final stats = results[3] as Map<String, dynamic>;

      final now = DateTime.now();

      // Split bookings into upcoming vs past
      final upcoming = <Map<String, dynamic>>[];
      final past = <Map<String, dynamic>>[];
      for (final b in allBookings) {
        final startStr = b['start_time'] as String?;
        if (startStr == null) continue;
        final start = DateTime.tryParse(startStr);
        if (start == null) continue;

        final status = (b['status'] as String?) ?? '';
        if (status == 'cancelled') continue; // skip cancelled

        if (start.isAfter(now) &&
            (status == 'confirmed' || status == 'pending')) {
          upcoming.add(b);
        } else {
          past.add(b);
        }
      }

      // Sort upcoming by soonest first
      upcoming.sort((a, b) {
        final aTime = DateTime.tryParse(a['start_time'] ?? '') ?? now;
        final bTime = DateTime.tryParse(b['start_time'] ?? '') ?? now;
        return aTime.compareTo(bTime);
      });

      // Sort past by most recent first
      past.sort((a, b) {
        final aTime = DateTime.tryParse(a['start_time'] ?? '') ?? now;
        final bTime = DateTime.tryParse(b['start_time'] ?? '') ?? now;
        return bTime.compareTo(aTime);
      });

      emit(state.copyWith(
        status: DashboardStatus.loaded,
        upcomingLessons: upcoming,
        pastLessons: past,
        lessonRequests: requests,
        mySheikhs: sheikhs,
        stats: stats,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: DashboardStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onChangeTab(
      ChangeTab event, Emitter<StudentDashboardState> emit) {
    emit(state.copyWith(selectedTab: event.tabIndex));
  }

  Future<void> _onCancelBooking(
      CancelStudentBooking event, Emitter<StudentDashboardState> emit) async {
    try {
      await _datasource.cancelBooking(event.bookingId);
      add(const LoadDashboard());
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> _onSubmitReview(
      SubmitSheikhReview event, Emitter<StudentDashboardState> emit) async {
    try {
      await _datasource.submitReview(
        sheikhId: event.sheikhId,
        rating: event.rating,
        comment: event.comment,
        lessonRequestId: event.lessonRequestId,
      );
      emit(state.copyWith(reviewMessage: 'Review submitted!'));
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }
}
