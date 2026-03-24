import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Simplified map filters — discovery-first, no complexity.
class MapFilters extends Equatable {
  final double radiusKm;
  final Set<String> categories; // quran, lecture, charity, etc.
  final String eventType; // 'all', 'online', 'in_person'
  final String search;

  const MapFilters({
    this.radiusKm = 10,
    this.categories = const {},
    this.eventType = 'all',
    this.search = '',
  });

  MapFilters copyWith({
    double? radiusKm,
    Set<String>? categories,
    String? eventType,
    String? search,
  }) {
    return MapFilters(
      radiusKm: radiusKm ?? this.radiusKm,
      categories: categories ?? this.categories,
      eventType: eventType ?? this.eventType,
      search: search ?? this.search,
    );
  }

  @override
  List<Object?> get props => [radiusKm, categories, eventType, search];
}

class MapEvent extends Equatable {
  final String id;
  final String organizationId;
  final String title;
  final String organization;
  final String category;
  final double latitude;
  final double longitude;
  final DateTime startsAt;
  final DateTime? endsAt;
  final int? capacity;
  final int reservedCount;
  final int? remainingSeats;
  final String? genderRestriction;
  final int? minAge;
  final int? maxAge;
  final double distanceKm;
  final String trustLevel;
  final bool isTrending;
  final double recommendationScore;
  final bool recommended;
  final bool endingSoon;

  const MapEvent({
    required this.id,
    required this.organizationId,
    required this.title,
    required this.organization,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.startsAt,
    this.endsAt,
    this.capacity,
    required this.reservedCount,
    this.remainingSeats,
    this.genderRestriction,
    this.minAge,
    this.maxAge,
    required this.distanceKm,
    required this.trustLevel,
    required this.isTrending,
    required this.recommendationScore,
    required this.recommended,
    required this.endingSoon,
  });

  LatLng get point => LatLng(latitude, longitude);

  bool get isOnline => latitude == 0 && longitude == 0;

  factory MapEvent.fromJson(Map<String, dynamic> json) {
    return MapEvent(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      title: json['title'] as String,
      organization: json['organization'] as String? ?? 'Organization',
      category: json['category'] as String? ?? 'general',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
      capacity: json['capacity'] as int?,
      reservedCount: json['reserved_count'] as int? ?? 0,
      remainingSeats: json['remaining_seats'] as int?,
      genderRestriction: json['gender_restriction'] as String?,
      minAge: json['min_age'] as int?,
      maxAge: json['max_age'] as int?,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      trustLevel: json['trust_level'] as String? ?? 'basic',
      isTrending: json['is_trending'] as bool? ?? false,
      recommendationScore:
          (json['recommendation_score'] as num?)?.toDouble() ?? 0,
      recommended: json['recommended'] as bool? ?? false,
      endingSoon: json['ending_soon'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        organizationId,
        title,
        organization,
        category,
        latitude,
        longitude,
        startsAt,
        endsAt,
        capacity,
        reservedCount,
        remainingSeats,
        genderRestriction,
        minAge,
        maxAge,
        distanceKm,
        trustLevel,
        isTrending,
        recommendationScore,
        recommended,
        endingSoon,
      ];
}

class NearbyMapResult extends Equatable {
  final List<MapEvent> events;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool hasNextPage;

  const NearbyMapResult({
    required this.events,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.hasNextPage,
  });

  factory NearbyMapResult.fromJson(Map<String, dynamic> json) {
    final rawEvents = (json['events'] as List<dynamic>? ?? const []);
    return NearbyMapResult(
      events: rawEvents
          .map((e) => MapEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 60,
      totalCount: json['total_count'] as int? ?? 0,
      hasNextPage: json['has_next_page'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [events, page, pageSize, totalCount, hasNextPage];
}

class MapClusterNode extends Equatable {
  final String key;
  final LatLng center;
  final List<MapEvent> events;

  const MapClusterNode({
    required this.key,
    required this.center,
    required this.events,
  });

  bool get isCluster => events.length > 1;
  int get count => events.length;
  MapEvent? get singleEvent => isCluster ? null : events.first;

  @override
  List<Object?> get props => [key, center, events];
}
