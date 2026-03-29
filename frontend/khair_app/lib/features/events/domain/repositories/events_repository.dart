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
  Future<Either<Failure, Event>> updateEvent(String id, UpdateEventParams params);
  Future<Either<Failure, void>> deleteEvent(String id);
  Future<Either<Failure, Event>> submitForReview(String id);
}

class CreateEventParams {
  final String title;
  final String? description;
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
  final double? ticketPrice;
  final String? currency;

  const CreateEventParams({
    required this.title,
    this.description,
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
    this.ticketPrice,
    this.currency,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
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
      'ticket_price': ticketPrice,
      'currency': currency,
    };
  }
}

class UpdateEventParams {
  final String? title;
  final String? description;
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
  final double? ticketPrice;
  final String? currency;

  const UpdateEventParams({
    this.title,
    this.description,
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
    this.ticketPrice,
    this.currency,
  });

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    if (title != null) json['title'] = title;
    if (description != null) json['description'] = description;
    if (eventType != null) json['event_type'] = eventType;
    if (language != null) json['language'] = language;
    if (country != null) json['country'] = country;
    if (city != null) json['city'] = city;
    if (address != null) json['address'] = address;
    if (latitude != null) json['latitude'] = latitude;
    if (longitude != null) json['longitude'] = longitude;
    if (startDate != null) json['start_date'] = startDate!.toUtc().toIso8601String();
    if (endDate != null) json['end_date'] = endDate!.toUtc().toIso8601String();
    if (imageUrl != null) json['image_url'] = imageUrl;
    if (ticketPrice != null) json['ticket_price'] = ticketPrice;
    if (currency != null) json['currency'] = currency;
    return json;
  }
}
