import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/auth/auth_session_controller.dart';
import '../../../../core/push/push_notification_service_platform.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  late final StreamSubscription<void> _sessionExpirySubscription;

  AuthBloc(this._authRepository, AuthSessionController sessionController)
      : super(const AuthState()) {
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<AuthSessionExpired>(_onSessionExpired);
    on<GoogleLoginRequested>(_onGoogleLoginRequested);
    on<OrganizerSessionChanged>(_onOrganizerSessionChanged);
    _sessionExpirySubscription = sessionController.expired.listen(
      (_) => add(const AuthSessionExpired()),
    );
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    final isAuthenticated = await _authRepository.isAuthenticated();
    if (isAuthenticated) {
      final userResult = await _authRepository.getCurrentUser();
      final organizerResult = await _authRepository.getCurrentOrganizer();
      userResult.fold(
        (_) => emit(const AuthState(status: AuthStatus.unauthenticated)),
        (user) => organizerResult.fold(
          (_) => emit(AuthState(status: AuthStatus.authenticated, user: user)),
          (organizer) => emit(AuthState(
            status: AuthStatus.authenticated,
            user: user,
            organizer: organizer,
          )),
        ),
      );
    } else {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await _authRepository.login(event.email, event.password);

    result.fold(
      (failure) => emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: failure.message,
      )),
      (response) => emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
        organizer: response.organizer,
      )),
    );
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    final result = await _authRepository.register(
      event.email,
      event.password,
      event.name,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: failure.message,
      )),
      (response) => emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
        organizer: response.organizer,
      )),
    );
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Keep the authenticated API session alive long enough to deactivate this
    // device token. A later user on the same phone cannot receive this user's
    // notifications even if the FCM token itself is reused.
    await PushNotificationService.instance.removeToken();
    PushNotificationService.instance.clearSession();
    await _authRepository.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) {
    PushNotificationService.instance.clearSession();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onGoogleLoginRequested(
    GoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _authRepository.loginWithGoogle(
      event.idToken,
      event.preferredLanguage,
    );
    result.fold(
      (failure) => emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: failure.message,
      )),
      (response) => emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
        organizer: response.organizer,
      )),
    );
  }

  Future<void> _onOrganizerSessionChanged(
    OrganizerSessionChanged event,
    Emitter<AuthState> emit,
  ) async {
    await _authRepository.saveOrganizer(event.organizer);
    emit(state.copyWith(organizer: event.organizer));
  }

  @override
  Future<void> close() async {
    await _sessionExpirySubscription.cancel();
    return super.close();
  }
}
