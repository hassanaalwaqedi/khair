import 'package:equatable/equatable.dart';

/// Organizer entity representing an event organizer
class Organizer extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String organizationType;
  final String? description;
  final String? street;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;
  final String status; // pending, approved, rejected
  final String? rejectionReason;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Organizer({
    required this.id,
    required this.userId,
    required this.name,
    required this.organizationType,
    this.description,
    this.street,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.phone,
    this.email,
    this.website,
    required this.status,
    this.rejectionReason,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Organizer.fromJson(Map<String, dynamic> json) {
    return Organizer(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      organizationType: json['organization_type'],
      description: json['description'],
      street: json['street'],
      city: json['city'],
      state: json['state'],
      postalCode: json['postal_code'],
      country: json['country'],
      phone: json['phone'],
      email: json['email'],
      website: json['website'],
      status: json['status'],
      rejectionReason: json['rejection_reason'],
      isVerified: json['is_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'organization_type': organizationType,
      'description': description,
      'street': street,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'country': country,
      'phone': phone,
      'email': email,
      'website': website,
      'status': status,
      'rejection_reason': rejectionReason,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        organizationType,
        description,
        street,
        city,
        state,
        postalCode,
        country,
        phone,
        email,
        website,
        status,
        rejectionReason,
        isVerified,
        createdAt,
        updatedAt,
      ];
}

/// Admin message sent to organizer
class AdminMessage extends Equatable {
  final String id;
  final String organizerId;
  final String subject;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const AdminMessage({
    required this.id,
    required this.organizerId,
    required this.subject,
    required this.message,
    this.isRead = false,
    required this.createdAt,
  });

  factory AdminMessage.fromJson(Map<String, dynamic> json) {
    return AdminMessage(
      id: json['id'],
      organizerId: json['organizer_id'],
      subject: json['subject'],
      message: json['message'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  @override
  List<Object?> get props => [id, organizerId, subject, message, isRead, createdAt];
}
