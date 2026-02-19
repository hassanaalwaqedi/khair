import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/organizer.dart';
import '../../../events/domain/entities/event.dart';

/// Repository interface for organizer operations
abstract class OrganizerRepository {
  /// Get the current organizer's profile
  Future<Either<Failure, Organizer>> getMyProfile();

  /// Get organizer by ID (public view)
  Future<Either<Failure, Organizer>> getOrganizerById(String id);

  /// Update organizer profile
  Future<Either<Failure, Organizer>> updateProfile(UpdateProfileParams params);

  /// Get events created by the current organizer
  Future<Either<Failure, List<Event>>> getMyEvents();

  /// Get admin messages for the current organizer
  Future<Either<Failure, List<AdminMessage>>> getAdminMessages();

  /// Mark admin message as read
  Future<Either<Failure, void>> markMessageAsRead(String messageId);

  /// Apply to become an organizer
  Future<Either<Failure, Organizer>> applyAsOrganizer(OrganizerApplicationParams params);
}

/// Parameters for updating organizer profile
class UpdateProfileParams {
  final String? name;
  final String? description;
  final String? street;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? phone;
  final String? email;
  final String? website;

  const UpdateProfileParams({
    this.name,
    this.description,
    this.street,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.phone,
    this.email,
    this.website,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (description != null) map['description'] = description;
    if (street != null) map['street'] = street;
    if (city != null) map['city'] = city;
    if (state != null) map['state'] = state;
    if (postalCode != null) map['postal_code'] = postalCode;
    if (country != null) map['country'] = country;
    if (phone != null) map['phone'] = phone;
    if (email != null) map['email'] = email;
    if (website != null) map['website'] = website;
    return map;
  }
}

/// Parameters for organizer application
class OrganizerApplicationParams {
  final String name;
  final String organizationType;
  final String? description;
  final String? street;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String phone;
  final String email;
  final String? website;

  const OrganizerApplicationParams({
    required this.name,
    required this.organizationType,
    this.description,
    this.street,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    required this.phone,
    required this.email,
    this.website,
  });

  Map<String, dynamic> toJson() {
    return {
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
    };
  }
}
