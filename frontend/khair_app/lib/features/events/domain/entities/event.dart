import 'package:equatable/equatable.dart';

import 'attendance_policy.dart';

class EventPricing extends Equatable {
  final String type; // "free" or "paid"
  final int? amountCents;
  final String? currency;
  final String? paymentMethod;

  const EventPricing({
    required this.type,
    this.amountCents,
    this.currency,
    this.paymentMethod,
  });

  bool get isFree => type == 'free';
  bool get isPaid => type == 'paid';

  @override
  List<Object?> get props => [type, amountCents, currency, paymentMethod];
}

class Event extends Equatable {
  final String id;
  final String organizerId;
  final String title;
  final String? description;
  final String eventType;
  final String? category;
  final List<String> tags;
  final String? language;
  final String? country;
  final String? city;
  final String? address;
  final String? fullAddress;
  final double? latitude;
  final double? longitude;
  final String? meetingUrl;
  final String? meetingPlatform;
  final DateTime startDate;
  final DateTime? endDate;
  final String? imageUrl;
  final int? capacity;
  final int reservedCount;
  final String status;
  final String? rejectionReason;
  final String? organizerName;
  final bool isOnline;
  final String? onlineLink;
  final String? joinInstructions;
  final int joinLinkVisibleBeforeMinutes;
  final String? venueName;
  final String? onlinePlatform;
  final DateTime? registrationDeadline;
  final String? registrationMode;
  final bool registrationRequired;
  final String registrationType; // none | khair | external | both
  final String? externalPlatformName;
  final String? externalRegistrationUrl;
  final String? externalRegistrationInstructions;
  final String? registrationRequirements;
  final bool applicationApprovalRequired;
  final String? timezone;
  final String? genderRestriction;
  final String attendancePolicy;
  final bool isUserJoined;
  final bool isLinkUnlocked;
  final String externalRegistrationStatus;
  final DateTime? externalRegistrationReminderDismissedAt;
  final DateTime? externalRegistrationLinkOpenedAt;
  final DateTime? externalRegistrationSelfReportedCompletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final EventPricing pricing;

  const Event({
    required this.id,
    required this.organizerId,
    required this.title,
    this.description,
    required this.eventType,
    this.category,
    this.tags = const [],
    this.language,
    this.country,
    this.city,
    this.address,
    this.fullAddress,
    this.latitude,
    this.longitude,
    this.meetingUrl,
    this.meetingPlatform,
    required this.startDate,
    this.endDate,
    this.imageUrl,
    this.capacity,
    this.reservedCount = 0,
    required this.status,
    this.rejectionReason,
    this.organizerName,
    this.isOnline = false,
    this.onlineLink,
    this.joinInstructions,
    this.joinLinkVisibleBeforeMinutes = 15,
    this.venueName,
    this.onlinePlatform,
    this.registrationDeadline,
    this.registrationMode,
    this.registrationRequired = false,
    this.registrationType = 'none',
    this.externalPlatformName,
    this.externalRegistrationUrl,
    this.externalRegistrationInstructions,
    this.registrationRequirements,
    this.applicationApprovalRequired = false,
    this.timezone,
    this.genderRestriction,
    this.attendancePolicy = AttendancePolicy.everyone,
    this.isUserJoined = false,
    this.isLinkUnlocked = false,
    this.externalRegistrationStatus = 'not_required',
    this.externalRegistrationReminderDismissedAt,
    this.externalRegistrationLinkOpenedAt,
    this.externalRegistrationSelfReportedCompletedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.pricing,
  });

  @override
  List<Object?> get props => [
        id,
        organizerId,
        title,
        description,
        eventType,
        category,
        tags,
        language,
        country,
        city,
        address,
        fullAddress,
        latitude,
        longitude,
        meetingUrl,
        meetingPlatform,
        startDate,
        endDate,
        imageUrl,
        capacity,
        reservedCount,
        status,
        rejectionReason,
        organizerName,
        isOnline,
        onlineLink,
        joinInstructions,
        joinLinkVisibleBeforeMinutes,
        venueName,
        onlinePlatform,
        registrationDeadline,
        registrationMode,
        registrationRequired,
        registrationType,
        externalPlatformName,
        externalRegistrationUrl,
        externalRegistrationInstructions,
        registrationRequirements,
        applicationApprovalRequired,
        timezone,
        genderRestriction,
        attendancePolicy,
        isUserJoined,
        isLinkUnlocked,
        externalRegistrationStatus,
        externalRegistrationReminderDismissedAt,
        externalRegistrationLinkOpenedAt,
        externalRegistrationSelfReportedCompletedAt,
        createdAt,
        updatedAt,
        pricing,
      ];

  String get effectiveAttendancePolicy =>
      AttendancePolicy.normalize(attendancePolicy == AttendancePolicy.everyone
          ? genderRestriction
          : attendancePolicy);

  bool get isRestrictedEvent =>
      effectiveAttendancePolicy != AttendancePolicy.everyone;
}

enum DateFilter { today, thisWeek, thisWeekend, thisMonth }

class EventFilter extends Equatable {
  final String? country;
  final String? city;
  final String? eventType;
  final String? category;
  final String? language;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;
  final DateFilter? dateFilter;
  final String? pricingType;
  final double? latitude;
  final double? longitude;
  final double? radiusKm;
  final String? timezone;
  final bool onlineOnly;
  final bool freeOnly;
  final bool trending;
  final int page;
  final int pageSize;

  const EventFilter({
    this.country,
    this.city,
    this.eventType,
    this.category,
    this.language,
    this.startDate,
    this.endDate,
    this.searchQuery,
    this.dateFilter,
    this.pricingType,
    this.latitude,
    this.longitude,
    this.radiusKm,
    this.timezone,
    this.onlineOnly = false,
    this.freeOnly = false,
    this.trending = false,
    this.page = 1,
    this.pageSize = 20,
  });

  EventFilter copyWith({
    String? country,
    String? city,
    String? eventType,
    String? category,
    String? language,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    DateFilter? dateFilter,
    String? pricingType,
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? timezone,
    bool? onlineOnly,
    bool? freeOnly,
    bool? trending,
    int? page,
    int? pageSize,
    bool clearCountry = false,
    bool clearCity = false,
    bool clearEventType = false,
    bool clearCategory = false,
    bool clearLanguage = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearSearchQuery = false,
    bool clearDateFilter = false,
    bool clearPricingType = false,
    bool clearLatitude = false,
    bool clearLongitude = false,
    bool clearRadiusKm = false,
    bool clearTimezone = false,
  }) {
    return EventFilter(
      country: clearCountry ? null : country ?? this.country,
      city: clearCity ? null : city ?? this.city,
      eventType: clearEventType ? null : eventType ?? this.eventType,
      category: clearCategory ? null : category ?? this.category,
      language: clearLanguage ? null : language ?? this.language,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      searchQuery: clearSearchQuery ? null : searchQuery ?? this.searchQuery,
      dateFilter: clearDateFilter ? null : dateFilter ?? this.dateFilter,
      pricingType: clearPricingType ? null : pricingType ?? this.pricingType,
      latitude: clearLatitude ? null : latitude ?? this.latitude,
      longitude: clearLongitude ? null : longitude ?? this.longitude,
      radiusKm: clearRadiusKm ? null : radiusKm ?? this.radiusKm,
      timezone: clearTimezone ? null : timezone ?? this.timezone,
      onlineOnly: onlineOnly ?? this.onlineOnly,
      freeOnly: freeOnly ?? this.freeOnly,
      trending: trending ?? this.trending,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  /// Clear all temporary filters (including temporary location)
  EventFilter clearFilters() {
    return EventFilter(
      page: 1,
      pageSize: pageSize,
      timezone: timezone,
    );
  }

  /// Check if any temporary filter is active
  bool get hasActiveFilters =>
      country != null ||
      city != null ||
      eventType != null ||
      category != null ||
      language != null ||
      dateFilter != null ||
      searchQuery != null ||
      pricingType != null ||
      latitude != null ||
      longitude != null ||
      radiusKm != null ||
      onlineOnly ||
      freeOnly ||
      trending;

  Map<String, dynamic> toQueryParameters() {
    final params = <String, dynamic>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
    };

    if (country != null) params['country'] = country;
    if (city != null) params['city'] = city;
    if (eventType != null) params['event_type'] = eventType;
    if (category != null) params['category'] = category;
    if (language != null) params['language'] = language;
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      params['search'] = searchQuery;
    }
    if (trending) params['trending'] = 'true';
    if (onlineOnly) params['is_online'] = 'true';
    if (freeOnly) {
      params['pricing_type'] = 'free';
      params['free'] =
          'true'; // compatibility with existing discovery API clients
    }
    if (pricingType != null && !freeOnly) params['pricing_type'] = pricingType;
    if (latitude != null && longitude != null) {
      params['lat'] = latitude.toString();
      params['lng'] = longitude.toString();
      params['radius'] = (radiusKm ?? 10).toString();
    }

    // Date presets are interpreted by the backend in the user's timezone.
    if (dateFilter != null) {
      params['date'] = switch (dateFilter!) {
        DateFilter.today => 'today',
        DateFilter.thisWeek => 'this_week',
        DateFilter.thisWeekend => 'this_weekend',
        DateFilter.thisMonth => 'this_month',
      };
      if (timezone != null && timezone!.isNotEmpty) {
        params['timezone'] = timezone;
      }
    } else {
      if (startDate != null) {
        params['start_date'] = startDate!.toUtc().toIso8601String();
      }
      if (endDate != null) {
        params['end_date'] = endDate!.toUtc().toIso8601String();
      }
    }

    return params;
  }

  @override
  List<Object?> get props => [
        country,
        city,
        eventType,
        category,
        language,
        startDate,
        endDate,
        searchQuery,
        dateFilter,
        pricingType,
        latitude,
        longitude,
        radiusKm,
        timezone,
        onlineOnly,
        freeOnly,
        trending,
        page,
        pageSize,
      ];
}
