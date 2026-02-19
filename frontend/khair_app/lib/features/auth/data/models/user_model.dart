import '../../domain/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.email,
    required super.role,
    required super.createdAt,
    required super.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class OrganizerModel extends Organizer {
  const OrganizerModel({
    required super.id,
    required super.userId,
    required super.name,
    super.description,
    super.website,
    super.phone,
    super.logoUrl,
    required super.status,
    super.rejectionReason,
    required super.createdAt,
    required super.updatedAt,
  });

  factory OrganizerModel.fromJson(Map<String, dynamic> json) {
    return OrganizerModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      website: json['website'] as String?,
      phone: json['phone'] as String?,
      logoUrl: json['logo_url'] as String?,
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class AuthResponseModel extends AuthResponse {
  const AuthResponseModel({
    required super.token,
    required super.expiresAt,
    required super.user,
    super.organizer,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      organizer: json['organizer'] != null
          ? OrganizerModel.fromJson(json['organizer'] as Map<String, dynamic>)
          : null,
    );
  }
}
