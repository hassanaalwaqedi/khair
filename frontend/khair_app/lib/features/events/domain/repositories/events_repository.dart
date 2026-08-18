import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/event.dart';

abstract class EventsRepository {
  Future<Either<Failure, List<Event>>> getEvents(EventFilter filter);
  Future<Either<Failure, Event>> getEventById(String id);
  Future<Either<Failure, List<Event>>> getNearbyEvents({
    required double latitude,
    required double longitude,
    double radius = 10,
    String? eventType,
    String? language,
    int limit = 50,
  });
  Future<Either<Failure, List<Event>>> getMyEvents();
  Future<Either<Failure, Event>> createEvent(CreateEventParams params);
  Future<Either<Failure, Event>> createDraft(CreateEventParams params);
  Future<Either<Failure, Event>> updateEvent(
      String id, UpdateEventParams params);
  Future<Either<Failure, void>> deleteEvent(String id);
  Future<Either<Failure, Event>> submitForReview(String id);
  Future<Either<Failure, Map<String, dynamic>>> getMeetingAccess(String id);
}

class CreateEventParams {
  final String title;
  final String? description;
  final String? category;
  final List<String> tags;
  final String eventType;
  final String? language;
  final String? country;
  final String? city;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime startDate;
  final DateTime? endDate;
  final String? imageUrl;
  final EventPricing? pricing;
  final bool isOnline;
  final String? onlinePlatform;
  final String? onlineLink;
  final String? joinInstructions;
  final String? venueName;
  final int? capacity;
  final String? genderRestriction;
  final int? ageMin;
  final DateTime? registrationDeadline;
  final String? registrationMode;
  final String? timezone;
  final String? guidelines;

  const CreateEventParams({
    required this.title,
    this.description,
    this.category,
    this.tags = const [],
    required this.eventType,
    this.language,
    this.country,
    this.city,
    this.address,
    this.latitude,
    this.longitude,
    required this.startDate,
    this.endDate,
    this.imageUrl,
    this.pricing,
    this.isOnline = false,
    this.onlinePlatform,
    this.onlineLink,
    this.joinInstructions,
    this.venueName,
    this.capacity,
    this.genderRestriction,
    this.ageMin,
    this.registrationDeadline,
    this.registrationMode,
    this.timezone,
    this.guidelines,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'tags': tags,
      'event_type': eventType,
      'language': language,
      'country': country,
      'city': city,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'start_date': startDate.toUtc().toIso8601String(),
      'end_date': endDate?.toUtc().toIso8601String(),
      'image_url': imageUrl,
      if (pricing != null)
        'pricing': {
          'type': pricing!.type,
          'amount_cents': pricing!.amountCents,
          'currency': pricing!.currency,
          'payment_method': pricing!.paymentMethod,
        },
      'is_online': isOnline,
      'online_platform': onlinePlatform,
      'online_link': onlineLink,
      'join_instructions': joinInstructions,
      'venue_name': venueName,
      'capacity': capacity,
      'gender_restriction': genderRestriction,
      'age_min': ageMin,
      'registration_deadline': registrationDeadline?.toUtc().toIso8601String(),
      'registration_mode': registrationMode,
      'timezone': timezone,
      'guidelines': guidelines,
    };
  }

  UpdateEventParams toUpdateParams() => UpdateEventParams(
        title: title,
        description: description,
        category: category,
        tags: tags,
        eventType: eventType,
        language: language,
        country: country,
        city: city,
        address: address,
        latitude: latitude,
        longitude: longitude,
        startDate: startDate,
        endDate: endDate,
        imageUrl: imageUrl,
        isOnline: isOnline,
        onlineLink: onlineLink,
        joinInstructions: joinInstructions,
        venueName: venueName,
        capacity: capacity,
        genderRestriction: genderRestriction,
        ageMin: ageMin,
        registrationDeadline: registrationDeadline,
        registrationMode: registrationMode,
        timezone: timezone,
        guidelines: guidelines,
      );
}

class UpdateEventParams {
  final String? title;
  final String? description;
  final String? category;
  final List<String>? tags;
  final String? eventType;
  final String? language;
  final String? country;
  final String? city;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? imageUrl;
  final EventPricing? pricing;
  final bool? isOnline;
  final String? onlineLink;
  final String? joinInstructions;
  final String? venueName;
  final int? capacity;
  final String? genderRestriction;
  final int? ageMin;
  final DateTime? registrationDeadline;
  final String? registrationMode;
  final String? timezone;
  final String? guidelines;

  const UpdateEventParams({
    this.title,
    this.description,
    this.category,
    this.tags,
    this.eventType,
    this.language,
    this.country,
    this.city,
    this.address,
    this.latitude,
    this.longitude,
    this.startDate,
    this.endDate,
    this.imageUrl,
    this.pricing,
    this.isOnline,
    this.onlineLink,
    this.joinInstructions,
    this.venueName,
    this.capacity,
    this.genderRestriction,
    this.ageMin,
    this.registrationDeadline,
    this.registrationMode,
    this.timezone,
    this.guidelines,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (title != null) json['title'] = title;
    if (description != null) json['description'] = description;
    if (category != null) json['category'] = category;
    if (tags != null) json['tags'] = tags;
    if (eventType != null) json['event_type'] = eventType;
    if (language != null) json['language'] = language;
    if (country != null) json['country'] = country;
    if (city != null) json['city'] = city;
    if (address != null) json['address'] = address;
    if (latitude != null) json['latitude'] = latitude;
    if (longitude != null) json['longitude'] = longitude;
    if (startDate != null)
      json['start_date'] = startDate!.toUtc().toIso8601String();
    if (endDate != null) json['end_date'] = endDate!.toUtc().toIso8601String();
    if (imageUrl != null) json['image_url'] = imageUrl;
    if (pricing != null) {
      json['pricing'] = {
        'type': pricing!.type,
        'amount_cents': pricing!.amountCents,
        'currency': pricing!.currency,
        'payment_method': pricing!.paymentMethod,
      };
    }
    if (isOnline != null) json['is_online'] = isOnline;
    if (onlineLink != null) json['online_link'] = onlineLink;
    if (joinInstructions != null) json['join_instructions'] = joinInstructions;
    if (venueName != null) json['venue_name'] = venueName;
    if (capacity != null) json['capacity'] = capacity;
    if (genderRestriction != null)
      json['gender_restriction'] = genderRestriction;
    if (ageMin != null) json['age_min'] = ageMin;
    if (registrationDeadline != null) {
      json['registration_deadline'] =
          registrationDeadline!.toUtc().toIso8601String();
    }
    if (registrationMode != null) json['registration_mode'] = registrationMode;
    if (timezone != null) json['timezone'] = timezone;
    if (guidelines != null) json['guidelines'] = guidelines;
    return json;
  }
}
