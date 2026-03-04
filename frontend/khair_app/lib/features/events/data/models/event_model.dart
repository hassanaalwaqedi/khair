import '../../domain/entities/event.dart';

class EventModel extends Event {
  const EventModel({
    required super.id,
    required super.organizerId,
    required super.title,
    super.description,
    required super.eventType,
    super.language,
    super.country,
    super.city,
    super.address,
    super.latitude,
    super.longitude,
    required super.startDate,
    super.endDate,
    super.imageUrl,
    super.capacity,
    super.reservedCount,
    required super.status,
    super.rejectionReason,
    super.organizerName,
    required super.createdAt,
    required super.updatedAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      organizerId: json['organizer_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      eventType: json['event_type'] as String,
      language: json['language'] as String?,
      country: json['country'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: json['end_date'] != null
          ? DateTime.parse(json['end_date'] as String)
          : null,
      imageUrl: json['image_url'] as String?,
      capacity: json['capacity'] as int?,
      reservedCount: json['reserved_count'] as int? ?? 0,
      status: json['status'] as String,
      rejectionReason: json['rejection_reason'] as String?,
      organizerName: json['organizer_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organizer_id': organizerId,
      'title': title,
      'description': description,
      'event_type': eventType,
      'language': language,
      'country': country,
      'city': city,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'image_url': imageUrl,
      'capacity': capacity,
      'reserved_count': reservedCount,
      'status': status,
      'rejection_reason': rejectionReason,
      'organizer_name': organizerName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
