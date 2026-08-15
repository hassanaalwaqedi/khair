import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/datasources/registration_datasource.dart';

enum RegistrationStatus { initial, loading, pendingVerification, failure }

class RegistrationState extends Equatable {
  final RegistrationStatus status;
  final String? errorMessage;
  const RegistrationState(
      {this.status = RegistrationStatus.initial, this.errorMessage});
  RegistrationState copyWith(
          {RegistrationStatus? status, String? errorMessage}) =>
      RegistrationState(
          status: status ?? this.status, errorMessage: errorMessage);
  @override
  List<Object?> get props => [status, errorMessage];
}

abstract class RegistrationEvent extends Equatable {
  const RegistrationEvent();
  @override
  List<Object?> get props => [];
}

class SubmitSimpleRegistration extends RegistrationEvent {
  final String displayName;
  final String email;
  final String password;
  final String preferredLanguage;
  const SubmitSimpleRegistration(
      {required this.displayName,
      required this.email,
      required this.password,
      required this.preferredLanguage});
  @override
  List<Object?> get props => [displayName, email, password, preferredLanguage];
}

/// Attendee-only registration workflow. The server normalizes legacy clients
/// to the same role while organizer status remains a separate application.
class RegistrationBloc extends Bloc<RegistrationEvent, RegistrationState> {
  final RegistrationRemoteDataSource _dataSource;
  RegistrationBloc(this._dataSource) : super(const RegistrationState()) {
    on<SubmitSimpleRegistration>(_submit);
  }
  Future<void> _submit(
      SubmitSimpleRegistration event, Emitter<RegistrationState> emit) async {
    emit(state.copyWith(status: RegistrationStatus.loading));
    try {
      final step1 = await _dataSource.submitStep1(
          email: event.email,
          password: event.password,
          displayName: event.displayName,
          preferredLanguage: event.preferredLanguage);
      final draftId = step1['draft_id'] as String?;
      if (draftId == null) throw Exception('Registration setup failed');
      await _dataSource.submitStep4(draftId: draftId);
      emit(state.copyWith(status: RegistrationStatus.pendingVerification));
    } catch (error) {
      emit(state.copyWith(
          status: RegistrationStatus.failure,
          errorMessage: error.toString().replaceFirst('Exception: ', '')));
    }
  }
}
