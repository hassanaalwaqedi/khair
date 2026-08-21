import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthResponse>> login(String email, String password);
  Future<Either<Failure, AuthResponse>> register(
      String email, String password, String name);
  Future<Either<Failure, AuthResponse>> loginWithGoogle(
      String idToken, String preferredLanguage);
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, void>> deleteAccount();
  Future<Either<Failure, User?>> getCurrentUser();
  Future<Either<Failure, Organizer?>> getCurrentOrganizer();
  Future<Either<Failure, void>> saveOrganizer(Organizer organizer);
  Future<bool> isAuthenticated();
}
