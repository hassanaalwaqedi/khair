import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

/// Simplified map filters — discovery-first, no complexity.
class MapFilters extends Equatable {
  final double radiusKm;
  final Set<String> categories; // quran, lecture, charity, etc.
  final String eventType; // 'all', 'online', 'in_person'
  final String search;
  final String when; // any, today, tomorrow, weekend
  final bool freeOnly;

  const MapFilters({
    this.radiusKm = 10,
    this.categories = const {},
    this.eventType = 'all',
    this.search = '',
    this.when = 'any',
    this.freeOnly = false,
  });

  MapFilters copyWith({
    double? radiusKm,
    Set<String>? categories,
    String? eventType,
    String? search,
    String? when,
    bool? freeOnly,
  }) {
    return MapFilters(
      radiusKm: radiusKm ?? this.radiusKm,
      categories: categories ?? this.categories,
      eventType: eventType ?? this.eventType,
      search: search ?? this.search,
      when: when ?? this.when,
      freeOnly: freeOnly ?? this.freeOnly,
    );
  }

  @override
  List<Object?> get props =>
      [radiusKm, categories, eventType, search, when, freeOnly];
}

/// A category from Khair's canonical event-category catalogue.
///
/// The map keeps the stable slug for API filters while showing the database's
/// display name to people in the filter sheet.
class MapCategory extends Equatable {
  const MapCategory({required this.slug, required this.displayName});

  factory MapCategory.fromJson(Map<String, dynamic> json) {
    final slug = (json['slug'] ?? json['name'] ?? '').toString().trim();
    final displayName = (json['display_name'] ?? '').toString().trim();
    return MapCategory(
      slug: slug,
      displayName: displayName.isEmpty ? _titleCase(slug) : displayName,
    );
  }

  final String slug;
  final String displayName;

  @override
  List<Object?> get props => [slug, displayName];
}

class MapEvent extends Equatable {
  final String id;
  final String organizationId;
  final String title;
  final String organization;
  final String category;
  final String eventType;
  final String? imageUrl;
  final String? city;
  final String? address;
  final bool isOnlineEvent;
  final int priceCents;
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
    required this.eventType,
    this.imageUrl,
    this.city,
    this.address,
    required this.isOnlineEvent,
    required this.priceCents,
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

  bool get isOnline => isOnlineEvent || latitude == 0 && longitude == 0;

  String get locationLabel {
    if (isOnline) return 'Online event';
    return [address, city]
        .whereType<String>()
        .where((part) => part.isNotEmpty)
        .join(', ');
  }

  factory MapEvent.fromJson(Map<String, dynamic> json) {
    return MapEvent(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      title: json['title'] as String,
      organization: json['organization'] as String? ?? 'Organization',
      category: json['category'] as String? ?? 'general',
      eventType: json['event_type'] as String? ?? 'in_person',
      imageUrl: json['image_url'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      isOnlineEvent: json['is_online'] as bool? ?? false,
      priceCents: json['price_cents'] as int? ?? 0,
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
        eventType,
        imageUrl,
        city,
        address,
        isOnlineEvent,
        priceCents,
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
  MapEvent? get singleEvent => isCluster || events.isEmpty ? null : events.first;

  @override
  List<Object?> get props => [key, center, events];
}

String _titleCase(String value) => value
    .split(RegExp(r'[_\s-]+'))
    .where((part) => part.isNotEmpty)
    .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
    .join(' ');
