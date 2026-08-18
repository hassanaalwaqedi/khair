import 'package:equatable/equatable.dart';

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
  final String? timezone;
  final String? genderRestriction;
  final bool isUserJoined;
  final bool isLinkUnlocked;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double? ticketPrice;
  final String? currency;

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
    this.timezone,
    this.genderRestriction,
    this.isUserJoined = false,
    this.isLinkUnlocked = false,
    required this.createdAt,
    required this.updatedAt,
    this.ticketPrice,
    this.currency,
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
        timezone,
        genderRestriction,
        isUserJoined,
        isLinkUnlocked,
        createdAt,
        updatedAt,
        ticketPrice,
        currency,
      ];
}

enum DateFilter { today, thisWeek, thisWeekend, thisMonth }

class EventFilter extends Equatable {
  final String? country;
  final String? city;
  final String? eventType;
  final String? language;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? searchQuery;
  final DateFilter? dateFilter;
  final bool onlineOnly;
  final bool freeOnly;
  final bool trending;
  final int page;
  final int pageSize;

  const EventFilter({
    this.country,
    this.city,
    this.eventType,
    this.language,
    this.startDate,
    this.endDate,
    this.searchQuery,
    this.dateFilter,
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
    String? language,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    DateFilter? dateFilter,
    bool? onlineOnly,
    bool? freeOnly,
    bool? trending,
    int? page,
    int? pageSize,
    bool clearCountry = false,
    bool clearCity = false,
    bool clearEventType = false,
    bool clearLanguage = false,
    bool clearStartDate = false,
    bool clearEndDate = false,
    bool clearSearchQuery = false,
    bool clearDateFilter = false,
  }) {
    return EventFilter(
      country: clearCountry ? null : country ?? this.country,
      city: clearCity ? null : city ?? this.city,
      eventType: clearEventType ? null : eventType ?? this.eventType,
      language: clearLanguage ? null : language ?? this.language,
      startDate: clearStartDate ? null : startDate ?? this.startDate,
      endDate: clearEndDate ? null : endDate ?? this.endDate,
      searchQuery: clearSearchQuery ? null : searchQuery ?? this.searchQuery,
      dateFilter: clearDateFilter ? null : dateFilter ?? this.dateFilter,
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
    );
  }

  /// Check if any temporary filter is active
  bool get hasActiveFilters =>
      country != null ||
      city != null ||
      eventType != null ||
      language != null ||
      dateFilter != null ||
      searchQuery != null ||
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
    if (language != null) params['language'] = language;
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      params['search'] = searchQuery;
    }
    if (trending) params['trending'] = 'true';
    if (onlineOnly) params['is_online'] = 'true';
    if (freeOnly) params['free'] = 'true';

    // Compute date range from DateFilter enum
    if (dateFilter != null) {
      final now = DateTime.now();
      switch (dateFilter!) {
        case DateFilter.today:
          params['start_date'] =
              DateTime(now.year, now.month, now.day).toIso8601String();
          params['end_date'] =
              DateTime(now.year, now.month, now.day, 23, 59, 59)
                  .toIso8601String();
          break;
        case DateFilter.thisWeek:
          // Start from now, not beginning of week, to exclude past days
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6));
          params['start_date'] = now.toIso8601String();
          params['end_date'] =
              DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59)
                  .toIso8601String();
          break;
        case DateFilter.thisWeekend:
          final daysToSaturday = (6 - now.weekday) % 7;
          final saturday = now.add(Duration(
              days: daysToSaturday == 0 && now.weekday != 6
                  ? 7
                  : daysToSaturday));
          params['start_date'] =
              DateTime(saturday.year, saturday.month, saturday.day)
                  .toIso8601String();
          params['end_date'] = DateTime(
                  saturday.year, saturday.month, saturday.day + 1, 23, 59, 59)
              .toIso8601String();
          break;
        case DateFilter.thisMonth:
          // Start from now, not beginning of month, to exclude past days
          params['start_date'] = now.toIso8601String();
          params['end_date'] = DateTime(now.year, now.month + 1, 0, 23, 59, 59)
              .toIso8601String();
          break;
      }
    } else {
      if (startDate != null) {
        params['start_date'] = startDate!.toIso8601String();
      }
      if (endDate != null) {
        params['end_date'] = endDate!.toIso8601String();
      }
    }

    return params;
  }

  @override
  List<Object?> get props => [
        country,
        city,
        eventType,
        language,
        startDate,
        endDate,
        searchQuery,
        dateFilter,
        onlineOnly,
        freeOnly,
        trending,
        page,
        pageSize,
      ];
}
