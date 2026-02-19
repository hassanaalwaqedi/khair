part of 'auth_bloc.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, failure }

class AuthState extends Equatable {
  final AuthStatus status;
  final User? user;
  final Organizer? organizer;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.organizer,
    this.errorMessage,
  });

  bool get isOrganizer => user?.role == 'organizer';
  bool get isAdmin => user?.role == 'admin';
  bool get isApprovedOrganizer => organizer?.isApproved ?? false;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    Organizer? organizer,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      organizer: organizer ?? this.organizer,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, organizer, errorMessage];
}
