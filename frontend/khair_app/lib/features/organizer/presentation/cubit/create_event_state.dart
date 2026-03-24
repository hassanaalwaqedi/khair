import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Status of the create event flow
enum CreateEventStatus {
  initial,
  submitting,
  success,
  failure,
  draftSaved,
  imageUploading,
  aiGenerating,
}

/// Structured compliance settings — replaces individual booleans
class ComplianceSettings extends Equatable {
  final String genderPolicy; // 'mixed', 'male_only', 'female_only'
  final bool familyFriendly;
  final bool noMusic;
  final bool noInappropriateContent;
  final bool prayerBreakRequired;
  final bool complianceConfirmed;

  const ComplianceSettings({
    this.genderPolicy = 'mixed',
    this.familyFriendly = true,
    this.noMusic = true,
    this.noInappropriateContent = true,
    this.prayerBreakRequired = false,
    this.complianceConfirmed = false,
  });

  ComplianceSettings copyWith({
    String? genderPolicy,
    bool? familyFriendly,
    bool? noMusic,
    bool? noInappropriateContent,
    bool? prayerBreakRequired,
    bool? complianceConfirmed,
  }) {
    return ComplianceSettings(
      genderPolicy: genderPolicy ?? this.genderPolicy,
      familyFriendly: familyFriendly ?? this.familyFriendly,
      noMusic: noMusic ?? this.noMusic,
      noInappropriateContent:
          noInappropriateContent ?? this.noInappropriateContent,
      prayerBreakRequired: prayerBreakRequired ?? this.prayerBreakRequired,
      complianceConfirmed: complianceConfirmed ?? this.complianceConfirmed,
    );
  }

  /// Count how many compliance toggles are enabled
  int get enabledCount =>
      (familyFriendly ? 1 : 0) +
      (noMusic ? 1 : 0) +
      (noInappropriateContent ? 1 : 0) +
      (prayerBreakRequired ? 1 : 0);

  /// Risk level based on compliance (low/medium/high)
  String get riskLevel {
    if (enabledCount >= 3 && complianceConfirmed) return 'low';
    if (enabledCount >= 2) return 'medium';
    return 'high';
  }

  @override
  List<Object?> get props => [
        genderPolicy,
        familyFriendly,
        noMusic,
        noInappropriateContent,
        prayerBreakRequired,
        complianceConfirmed,
      ];
}

/// All form data for creating an event
class CreateEventFormData extends Equatable {
  // Step 1 — Basic Info
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final String eventType; // 'offline' or 'online'
  final String language;
  final DateTime startDate;
  final TimeOfDay startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;
  final int? ageMin;
  final int? ageMax;

  // Step 2 — Location
  final String? countryCode;
  final String? countryName;
  final String? city;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? onlinePlatform;
  final String? onlineLink;
  final String? onlinePassword;

  // Step 3 — Compliance
  final ComplianceSettings compliance;

  // Step 4 — Media & Details
  final String? coverImageUrl;
  final int capacity;
  final double price;
  final DateTime? registrationDeadline;
  final bool autoApproval;

  // Step 5 — Final confirmation
  final bool finalConfirmed;

  CreateEventFormData({
    this.title = '',
    this.description = '',
    this.category = 'conference',
    this.tags = const [],
    this.eventType = 'offline',
    this.language = 'en',
    DateTime? startDate,
    this.startTime = const TimeOfDay(hour: 9, minute: 0),
    this.endDate,
    this.endTime,
    this.ageMin,
    this.ageMax,
    this.countryCode,
    this.countryName,
    this.city,
    this.address,
    this.latitude,
    this.longitude,
    this.onlinePlatform = 'zoom',
    this.onlineLink,
    this.onlinePassword,
    this.compliance = const ComplianceSettings(),
    this.coverImageUrl,
    this.capacity = 100,
    this.price = 0,
    this.registrationDeadline,
    this.autoApproval = false,
    this.finalConfirmed = false,
  }) : startDate = startDate ?? DateTime.now().add(const Duration(days: 7));

  CreateEventFormData copyWith({
    String? title,
    String? description,
    String? category,
    List<String>? tags,
    String? eventType,
    String? language,
    DateTime? startDate,
    TimeOfDay? startTime,
    DateTime? endDate,
    TimeOfDay? endTime,
    int? ageMin,
    int? ageMax,
    String? countryCode,
    String? countryName,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    String? onlinePlatform,
    String? onlineLink,
    String? onlinePassword,
    ComplianceSettings? compliance,
    String? coverImageUrl,
    int? capacity,
    double? price,
    DateTime? registrationDeadline,
    bool? autoApproval,
    bool? finalConfirmed,
  }) {
    return CreateEventFormData(
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      eventType: eventType ?? this.eventType,
      language: language ?? this.language,
      startDate: startDate ?? this.startDate,
      startTime: startTime ?? this.startTime,
      endDate: endDate ?? this.endDate,
      endTime: endTime ?? this.endTime,
      ageMin: ageMin ?? this.ageMin,
      ageMax: ageMax ?? this.ageMax,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      city: city ?? this.city,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      onlinePlatform: onlinePlatform ?? this.onlinePlatform,
      onlineLink: onlineLink ?? this.onlineLink,
      onlinePassword: onlinePassword ?? this.onlinePassword,
      compliance: compliance ?? this.compliance,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      capacity: capacity ?? this.capacity,
      price: price ?? this.price,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      autoApproval: autoApproval ?? this.autoApproval,
      finalConfirmed: finalConfirmed ?? this.finalConfirmed,
    );
  }

  /// Combine date + time into a single DateTime
  DateTime get startDateTime => DateTime(
        startDate.year, startDate.month, startDate.day,
        startTime.hour, startTime.minute,
      );

  DateTime? get endDateTime {
    if (endDate == null) return null;
    final t = endTime ?? const TimeOfDay(hour: 17, minute: 0);
    return DateTime(endDate!.year, endDate!.month, endDate!.day, t.hour, t.minute);
  }

  @override
  List<Object?> get props => [
        title, description, category, tags, eventType, language,
        startDate, startTime, endDate, endTime, ageMin, ageMax,
        countryCode, countryName, city, address, latitude, longitude,
        onlinePlatform, onlineLink, onlinePassword,
        compliance, coverImageUrl, capacity, price,
        registrationDeadline, autoApproval, finalConfirmed,
      ];
}

/// Holds the entire wizard state
class CreateEventState extends Equatable {
  final int currentStep;
  final CreateEventFormData formData;
  final CreateEventStatus status;
  final String? errorMessage;

  CreateEventState({
    this.currentStep = 0,
    CreateEventFormData? formData,
    this.status = CreateEventStatus.initial,
    this.errorMessage,
  }) : formData = formData ?? CreateEventFormData();

  CreateEventState copyWith({
    int? currentStep,
    CreateEventFormData? formData,
    CreateEventStatus? status,
    String? errorMessage,
  }) {
    return CreateEventState(
      currentStep: currentStep ?? this.currentStep,
      formData: formData ?? this.formData,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }

  bool get isFirstStep => currentStep == 0;
  bool get isLastStep => currentStep == 4;

  @override
  List<Object?> get props => [currentStep, formData, status, errorMessage];
}
