import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  const User({
    required this.id,
    required this.email,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, email, role, createdAt, updatedAt];
}

class Organizer extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String? description;
  final String? website;
  final String? phone;
  final String? logoUrl;
  final String status;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Organizer({
    required this.id,
    required this.userId,
    required this.name,
    this.description,
    this.website,
    this.phone,
    this.logoUrl,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        description,
        website,
        phone,
        logoUrl,
        status,
        rejectionReason,
        createdAt,
        updatedAt,
      ];
}

class AuthResponse extends Equatable {
  final String token;
  final DateTime expiresAt;
  final User user;
  final Organizer? organizer;

  const AuthResponse({
    required this.token,
    required this.expiresAt,
    required this.user,
    this.organizer,
  });

  @override
  List<Object?> get props => [token, expiresAt, user, organizer];
}
