import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';

import '../../data/datasources/registration_datasource.dart';

// --- Role helpers ---

/// Roles that use the simplified 4-step flow
const _simpleRoles = {'new_muslim', 'student'};

/// Check if a role uses the simplified registration flow
bool isSimpleRole(String? role) => role != null && _simpleRoles.contains(role);

/// Returns the progress bar labels for a given role
List<String> stepsForRole(String? role) {
  if (isSimpleRole(role)) {
    return ['Role', 'Account', 'Goals', 'Review'];
  }
  return ['Role', 'Account', 'Goals', 'Upload', 'Review'];
}

// --- Events ---

abstract class RegistrationEvent extends Equatable {
  const RegistrationEvent();
  @override
  List<Object?> get props => [];
}

class SelectRole extends RegistrationEvent {
  final String role;
  const SelectRole(this.role);
  @override
  List<Object?> get props => [role];
}

/// Full-flow Step 1: credentials only (authority roles)
class SubmitStep1 extends RegistrationEvent {
  final String role;
  final String email;
  final String password;
  const SubmitStep1(
      {required this.role, required this.email, required this.password});
  @override
  List<Object?> get props => [role, email, password];
}

/// Simple-flow: Full Name + Email + Password → creates user + sends verification
class SubmitSimpleRegistration extends RegistrationEvent {
  final String role;
  final String displayName;
  final String email;
  final String password;
  const SubmitSimpleRegistration({
    required this.role,
    required this.displayName,
    required this.email,
    required this.password,
  });
  @override
  List<Object?> get props => [role, displayName, email, password];
}

class SubmitStep2 extends RegistrationEvent {
  final String displayName;
  final String bio;
  final String location;
  final String city;
  final String country;
  final String language;
  const SubmitStep2({
    required this.displayName,
    this.bio = '',
    this.location = '',
    this.city = '',
    this.country = '',
    this.language = 'en',
  });
  @override
  List<Object?> get props =>
      [displayName, bio, location, city, country, language];
}

class SubmitStep3 extends RegistrationEvent {
  final Map<String, dynamic> data;
  const SubmitStep3(this.data);
  @override
  List<Object?> get props => [data];
}

class SubmitStep4 extends RegistrationEvent {
  const SubmitStep4();
}

class SubmitVerificationCode extends RegistrationEvent {
  final String email;
  final String code;
  const SubmitVerificationCode({required this.email, required this.code});
  @override
  List<Object?> get props => [email, code];
}

class ResendVerificationCode extends RegistrationEvent {
  final String email;
  const ResendVerificationCode({required this.email});
  @override
  List<Object?> get props => [email];
}

class GoToStep extends RegistrationEvent {
  final int step;
  const GoToStep(this.step);
  @override
  List<Object?> get props => [step];
}

class UploadImage extends RegistrationEvent {
  final File imageFile;
  const UploadImage(this.imageFile);
  @override
  List<Object?> get props => [imageFile];
}

// --- State ---

enum RegistrationStatus {
  initial,
  loading,
  success,
  failure,
  pendingVerification,
  complete
}

class RegistrationState extends Equatable {
  final RegistrationStatus status;
  final int currentStep;
  final String? selectedRole;
  final String? draftId;
  final int completionScore;
  final List<Map<String, dynamic>> suggestions;
  final String? welcomeMessage;
  final String? errorMessage;
  final Map<String, dynamic> formData;
  final bool resendSuccess;
  final String? imageUrl;

  const RegistrationState({
    this.status = RegistrationStatus.initial,
    this.currentStep = 0,
    this.selectedRole,
    this.draftId,
    this.completionScore = 0,
    this.suggestions = const [],
    this.welcomeMessage,
    this.errorMessage,
    this.formData = const {},
    this.resendSuccess = false,
    this.imageUrl,
  });

  /// Total number of logical steps for the current role
  int get totalSteps => stepsForRole(selectedRole).length;

  /// Whether this is a simple role flow
  bool get isSimple => isSimpleRole(selectedRole);

  RegistrationState copyWith({
    RegistrationStatus? status,
    int? currentStep,
    String? selectedRole,
    String? draftId,
    int? completionScore,
    List<Map<String, dynamic>>? suggestions,
    String? welcomeMessage,
    String? errorMessage,
    Map<String, dynamic>? formData,
    bool? resendSuccess,
    String? imageUrl,
  }) {
    return RegistrationState(
      status: status ?? this.status,
      currentStep: currentStep ?? this.currentStep,
      selectedRole: selectedRole ?? this.selectedRole,
      draftId: draftId ?? this.draftId,
      completionScore: completionScore ?? this.completionScore,
      suggestions: suggestions ?? this.suggestions,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      errorMessage: errorMessage ?? this.errorMessage,
      formData: formData ?? this.formData,
      resendSuccess: resendSuccess ?? this.resendSuccess,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentStep,
        selectedRole,
        draftId,
        completionScore,
        suggestions,
        welcomeMessage,
        errorMessage,
        formData,
        resendSuccess,
        imageUrl,
      ];
}

// --- BLoC ---

class RegistrationBloc extends Bloc<RegistrationEvent, RegistrationState> {
  final RegistrationRemoteDataSource _dataSource;

  RegistrationBloc(this._dataSource) : super(const RegistrationState()) {
    on<SelectRole>(_onSelectRole);
    on<SubmitStep1>(_onSubmitStep1);
    on<SubmitSimpleRegistration>(_onSubmitSimpleRegistration);
    on<SubmitStep2>(_onSubmitStep2);
    on<SubmitStep3>(_onSubmitStep3);
    on<SubmitStep4>(_onSubmitStep4);
    on<SubmitVerificationCode>(_onSubmitVerificationCode);
    on<ResendVerificationCode>(_onResendVerificationCode);
    on<GoToStep>(_onGoToStep);
    on<UploadImage>(_onUploadImage);
  }

  void _onSelectRole(SelectRole event, Emitter<RegistrationState> emit) {
    emit(state.copyWith(selectedRole: event.role, currentStep: 1));
  }

  void _onGoToStep(GoToStep event, Emitter<RegistrationState> emit) {
    if (event.step <= state.currentStep) {
      emit(state.copyWith(
          currentStep: event.step, status: RegistrationStatus.initial));
    }
  }

  // --- Full flow: Step 1 (credentials only, authority roles) ---

  Future<void> _onSubmitStep1(
    SubmitStep1 event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(status: RegistrationStatus.loading));
    try {
      final result = await _dataSource.submitStep1(
        role: event.role,
        email: event.email,
        password: event.password,
      );
      emit(state.copyWith(
        status: RegistrationStatus.success,
        currentStep: 2,
        draftId: result['draft_id'] as String?,
        completionScore: (result['completion_score'] as num?)?.toInt() ?? 0,
        suggestions: _parseSuggestions(result['suggestions']),
        formData: {...state.formData, 'email': event.email, 'role': event.role},
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RegistrationStatus.failure,
        errorMessage: _extractError(e),
      ));
    }
  }

  // --- Simple flow: credentials + full name → Step1 + Step4 chained ---

  Future<void> _onSubmitSimpleRegistration(
    SubmitSimpleRegistration event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(status: RegistrationStatus.loading));
    try {
      // Step 1: create draft with display_name included
      final step1Result = await _dataSource.submitStep1(
        role: event.role,
        email: event.email,
        password: event.password,
        displayName: event.displayName,
      );
      final draftId = step1Result['draft_id'] as String?;
      if (draftId == null) throw Exception('Failed to create registration');

      // Step 4: immediately finalize (skip steps 2-3)
      await _dataSource.submitStep4(draftId: draftId);

      // Move to verification step (index 2 in simple flow)
      emit(state.copyWith(
        status: RegistrationStatus.pendingVerification,
        currentStep: 2,
        draftId: draftId,
        formData: {
          ...state.formData,
          'email': event.email,
          'role': event.role,
          'display_name': event.displayName,
        },
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RegistrationStatus.failure,
        errorMessage: _extractError(e),
      ));
    }
  }

  // --- Full flow: Step 2 (profile info) ---

  Future<void> _onSubmitStep2(
    SubmitStep2 event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(status: RegistrationStatus.loading));
    try {
      final result = await _dataSource.submitStep2(
        draftId: state.draftId!,
        displayName: event.displayName,
        bio: event.bio,
        location: event.location,
        city: event.city,
        country: event.country,
        language: event.language,
      );
      emit(state.copyWith(
        status: RegistrationStatus.success,
        currentStep: 3,
        completionScore: (result['completion_score'] as num?)?.toInt() ?? 0,
        suggestions: _parseSuggestions(result['suggestions']),
        formData: {
          ...state.formData,
          'display_name': event.displayName,
          'bio': event.bio,
          'city': event.city,
          'country': event.country,
        },
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RegistrationStatus.failure,
        errorMessage: _extractError(e),
      ));
    }
  }

  // --- Full flow: Step 3 (role-specific details) ---

  Future<void> _onSubmitStep3(
    SubmitStep3 event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(status: RegistrationStatus.loading));
    try {
      final result = await _dataSource.submitStep3(
        draftId: state.draftId!,
        data: event.data,
      );
      emit(state.copyWith(
        status: RegistrationStatus.success,
        currentStep: 4,
        completionScore: (result['completion_score'] as num?)?.toInt() ?? 0,
        suggestions: _parseSuggestions(result['suggestions']),
        formData: {...state.formData, ...event.data},
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RegistrationStatus.failure,
        errorMessage: _extractError(e),
      ));
    }
  }

  // --- Full flow: Step 4 (review → finalize → verification) ---

  Future<void> _onSubmitStep4(
    SubmitStep4 event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(status: RegistrationStatus.loading));
    try {
      final result = await _dataSource.submitStep4(draftId: state.draftId!);
      emit(state.copyWith(
        status: RegistrationStatus.pendingVerification,
        currentStep: 5, // verification page in full flow
        completionScore: (result['completion_score'] as num?)?.toInt() ?? 0,
        welcomeMessage: result['welcome_message'] as String?,
        suggestions: _parseSuggestions(result['suggestions']),
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RegistrationStatus.failure,
        errorMessage: _extractError(e),
      ));
    }
  }

  // --- Shared: verify code ---

  Future<void> _onSubmitVerificationCode(
    SubmitVerificationCode event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
        status: RegistrationStatus.loading, resendSuccess: false));
    try {
      await _dataSource.verifyCode(email: event.email, code: event.code);
      // Move to the last step (done) — index depends on flow type
      final doneStep = state.isSimple ? 3 : 6;
      emit(state.copyWith(
        status: RegistrationStatus.complete,
        currentStep: doneStep,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RegistrationStatus.failure,
        errorMessage: _extractError(e),
      ));
    }
  }

  // --- Shared: resend code ---

  Future<void> _onResendVerificationCode(
    ResendVerificationCode event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(
        status: RegistrationStatus.loading, resendSuccess: false));
    try {
      await _dataSource.resendCode(email: event.email);
      emit(state.copyWith(
        status: RegistrationStatus.pendingVerification,
        resendSuccess: true,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RegistrationStatus.failure,
        errorMessage: _extractError(e),
      ));
    }
  }

  // --- Upload image ---

  Future<void> _onUploadImage(
    UploadImage event,
    Emitter<RegistrationState> emit,
  ) async {
    emit(state.copyWith(status: RegistrationStatus.loading));
    try {
      final url = await _dataSource.uploadImage(event.imageFile);
      emit(state.copyWith(
        status: RegistrationStatus.success,
        imageUrl: url,
        formData: {...state.formData, 'logo_url': url},
      ));
    } catch (e) {
      emit(state.copyWith(
        status: RegistrationStatus.failure,
        errorMessage: _extractError(e),
      ));
    }
  }

  List<Map<String, dynamic>> _parseSuggestions(dynamic raw) {
    if (raw is List) {
      return raw.cast<Map<String, dynamic>>();
    }
    return [];
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final apiError = data['error'] ?? data['message'];
        if (apiError is String && apiError.trim().isNotEmpty) {
          return apiError;
        }
      } else if (data is Map) {
        final apiError = data['error'] ?? data['message'];
        if (apiError is String && apiError.trim().isNotEmpty) {
          return apiError;
        }
      }

      final code = e.response?.statusCode;
      if (code != null) {
        return 'Request failed ($code). Please check your input and try again.';
      }
      return 'Network error. Please try again.';
    }

    if (e is Exception) {
      return e.toString().replaceAll('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }
}
