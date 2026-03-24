import 'package:equatable/equatable.dart';

class Event extends Equatable {
  final String id;
  final String organizerId;
  final String title;
  final String? description;
  final String eventType;
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
  final bool isUserJoined;
  final bool isLinkUnlocked;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Event({
    required this.id,
    required this.organizerId,
    required this.title,
    this.description,
    required this.eventType,
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
    this.isUserJoined = false,
    this.isLinkUnlocked = false,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        organizerId,
        title,
        description,
        eventType,
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
        isUserJoined,
        isLinkUnlocked,
        createdAt,
        updatedAt,
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
    bool? trending,
    int? page,
    int? pageSize,
  }) {
    return EventFilter(
      country: country ?? this.country,
      city: city ?? this.city,
      eventType: eventType ?? this.eventType,
      language: language ?? this.language,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      searchQuery: searchQuery ?? this.searchQuery,
      dateFilter: dateFilter ?? this.dateFilter,
      trending: trending ?? this.trending,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
    );
  }

  /// Clear all filters except location (country/city)
  EventFilter clearFilters() {
    return EventFilter(
      country: country,
      city: city,
      page: 1,
      pageSize: pageSize,
    );
  }

  /// Check if any non-location filter is active
  bool get hasActiveFilters =>
      eventType != null ||
      language != null ||
      dateFilter != null ||
      searchQuery != null ||
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

    // Compute date range from DateFilter enum
    if (dateFilter != null) {
      final now = DateTime.now();
      switch (dateFilter!) {
        case DateFilter.today:
          params['start_date'] = DateTime(now.year, now.month, now.day).toIso8601String();
          params['end_date'] = DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
          break;
        case DateFilter.thisWeek:
          // Start from now, not beginning of week, to exclude past days
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6));
          params['start_date'] = now.toIso8601String();
          params['end_date'] = DateTime(weekEnd.year, weekEnd.month, weekEnd.day, 23, 59, 59).toIso8601String();
          break;
        case DateFilter.thisWeekend:
          final daysToSaturday = (6 - now.weekday) % 7;
          final saturday = now.add(Duration(days: daysToSaturday == 0 && now.weekday != 6 ? 7 : daysToSaturday));
          params['start_date'] = DateTime(saturday.year, saturday.month, saturday.day).toIso8601String();
          params['end_date'] = DateTime(saturday.year, saturday.month, saturday.day + 1, 23, 59, 59).toIso8601String();
          break;
        case DateFilter.thisMonth:
          // Start from now, not beginning of month, to exclude past days
          params['start_date'] = now.toIso8601String();
          params['end_date'] = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();
          break;
      }
    } else {
      if (startDate != null) params['start_date'] = startDate!.toIso8601String();
      if (endDate != null) params['end_date'] = endDate!.toIso8601String();
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
        trending,
        page,
        pageSize,
      ];
}
