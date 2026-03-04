import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

enum MapDatePreset { any, today, weekend, custom }

enum ContextLayerType { mosque, islamicCenter, halalRestaurant }

extension ContextLayerTypeX on ContextLayerType {
  String get apiValue {
    switch (this) {
      case ContextLayerType.mosque:
        return 'mosque';
      case ContextLayerType.islamicCenter:
        return 'islamic_center';
      case ContextLayerType.halalRestaurant:
        return 'halal_restaurant';
    }
  }

  String get label {
    switch (this) {
      case ContextLayerType.mosque:
        return 'Mosques';
      case ContextLayerType.islamicCenter:
        return 'Islamic Centers';
      case ContextLayerType.halalRestaurant:
        return 'Halal Restaurants';
    }
  }
}

class MapFilters extends Equatable {
  final double radiusKm;
  final MapDatePreset datePreset;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? gender;
  final int? age;
  final Set<String> categories;
  final bool freeOnly;
  final bool almostFullOnly;
  final Set<ContextLayerType> contextLayers;
  final bool personalized;
  final String sortBy;

  const MapFilters({
    this.radiusKm = 10,
    this.datePreset = MapDatePreset.any,
    this.dateFrom,
    this.dateTo,
    this.gender,
    this.age,
    this.categories = const {},
    this.freeOnly = false,
    this.almostFullOnly = false,
    this.contextLayers = const {},
    this.personalized = false,
    this.sortBy = 'relevance',
  });

  MapFilters copyWith({
    double? radiusKm,
    MapDatePreset? datePreset,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? gender,
    int? age,
    Set<String>? categories,
    bool? freeOnly,
    bool? almostFullOnly,
    Set<ContextLayerType>? contextLayers,
    bool? personalized,
    String? sortBy,
    bool clearGender = false,
    bool clearDateRange = false,
  }) {
    return MapFilters(
      radiusKm: radiusKm ?? this.radiusKm,
      datePreset: datePreset ?? this.datePreset,
      dateFrom: clearDateRange ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateRange ? null : (dateTo ?? this.dateTo),
      gender: clearGender ? null : (gender ?? this.gender),
      age: age ?? this.age,
      categories: categories ?? this.categories,
      freeOnly: freeOnly ?? this.freeOnly,
      almostFullOnly: almostFullOnly ?? this.almostFullOnly,
      contextLayers: contextLayers ?? this.contextLayers,
      personalized: personalized ?? this.personalized,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  DateTime? get resolvedDateFrom {
    final now = DateTime.now();
    switch (datePreset) {
      case MapDatePreset.today:
        return DateTime(now.year, now.month, now.day);
      case MapDatePreset.weekend:
        final daysToSaturday = (6 - now.weekday) % 7;
        final saturday = now.add(Duration(days: daysToSaturday));
        return DateTime(saturday.year, saturday.month, saturday.day);
      case MapDatePreset.custom:
        return dateFrom;
      case MapDatePreset.any:
        return null;
    }
  }

  DateTime? get resolvedDateTo {
    final now = DateTime.now();
    switch (datePreset) {
      case MapDatePreset.today:
        return DateTime(now.year, now.month, now.day, 23, 59, 59);
      case MapDatePreset.weekend:
        final daysToSaturday = (6 - now.weekday) % 7;
        final saturday = now.add(Duration(days: daysToSaturday));
        return DateTime(
            saturday.year, saturday.month, saturday.day + 1, 23, 59, 59);
      case MapDatePreset.custom:
        return dateTo;
      case MapDatePreset.any:
        return null;
    }
  }

  @override
  List<Object?> get props => [
        radiusKm,
        datePreset,
        dateFrom,
        dateTo,
        gender,
        age,
        categories,
        freeOnly,
        almostFullOnly,
        contextLayers,
        personalized,
        sortBy,
      ];
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

class MapContextPlace extends Equatable {
  final String id;
  final String name;
  final String placeType;
  final String? address;
  final String? city;
  final String? country;
  final double latitude;
  final double longitude;
  final bool verified;

  const MapContextPlace({
    required this.id,
    required this.name,
    required this.placeType,
    this.address,
    this.city,
    this.country,
    required this.latitude,
    required this.longitude,
    required this.verified,
  });

  LatLng get point => LatLng(latitude, longitude);

  factory MapContextPlace.fromJson(Map<String, dynamic> json) {
    return MapContextPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      placeType: json['place_type'] as String,
      address: json['address'] as String?,
      city: json['city'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      verified: json['verified'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        placeType,
        address,
        city,
        country,
        latitude,
        longitude,
        verified,
      ];
}

class MapFilterOptions extends Equatable {
  final List<String> categories;
  final List<String> genderRestrictions;
  final List<int> radiusOptionsKm;

  const MapFilterOptions({
    required this.categories,
    required this.genderRestrictions,
    required this.radiusOptionsKm,
  });

  factory MapFilterOptions.fromJson(Map<String, dynamic> json) {
    return MapFilterOptions(
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      genderRestrictions:
          (json['gender_restrictions'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(),
      radiusOptionsKm:
          (json['radius_options_km'] as List<dynamic>? ?? const [5, 10, 25, 50])
              .map((e) => e as int)
              .toList(),
    );
  }

  @override
  List<Object?> get props => [categories, genderRestrictions, radiusOptionsKm];
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
