part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class RegisterRequested extends AuthEvent {
  final String email;
  final String password;
  final String name;

  const RegisterRequested({
    required this.email,
    required this.password,
    required this.name,
  });

  @override
  List<Object?> get props => [email, password, name];
}

class LogoutRequested extends AuthEvent {}

class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

class GoogleLoginRequested extends AuthEvent {
  final String idToken;
  final String preferredLanguage;

  const GoogleLoginRequested({
    required this.idToken,
    required this.preferredLanguage,
  });

  @override
  List<Object?> get props => [idToken, preferredLanguage];
}

class OrganizerSessionChanged extends AuthEvent {
  final Organizer organizer;

  const OrganizerSessionChanged(this.organizer);

  @override
  List<Object?> get props => [organizer];
}
