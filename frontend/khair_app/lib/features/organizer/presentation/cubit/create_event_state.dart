import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

enum CreateEventStatus {
  initial,
  saving,
  saved,
  submitting,
  success,
  failure,
  imageUploading,
  aiGenerating,
}

class CreateEventFormData extends Equatable {
  final String title;
  final String description;
  final String category;
  final List<String> tags;
  final String eventType; // offline | online
  final String language;
  final DateTime startDate;
  final TimeOfDay startTime;
  final DateTime? endDate;
  final TimeOfDay? endTime;
  final String timezone;
  final String? countryCode;
  final String? countryName;
  final String? city;
  final String? venueName;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? onlinePlatform;
  final String? onlineLink;
  final String? onlineInstructions;
  final String genderPolicy; // mixed | male_only | female_only
  final String agePolicy; // all_ages | 18_plus | families | custom
  final int? customMinAge;
  final bool unlimitedCapacity;
  final int? capacity;
  final DateTime? registrationDeadline;
  final String registrationMode; // instant | approval_required
  final String guidelines;
  final String pricingType; // free | paid
  final String? priceAmount;
  final String? currency;
  final String? paymentMethod;
  final String? coverImageUrl;

  /// Browser/mobile preview bytes shown while the permanent upload is pending
  /// or when the remote preview is temporarily unavailable.
  final Uint8List? coverImagePreviewBytes;
  final bool finalConfirmed;

  CreateEventFormData({
    this.title = '',
    this.description = '',
    this.category = '',
    this.tags = const [],
    this.eventType = 'offline',
    this.language = 'en',
    DateTime? startDate,
    this.startTime = const TimeOfDay(hour: 9, minute: 0),
    this.endDate,
    this.endTime,
    this.timezone = 'UTC',
    this.countryCode,
    this.countryName,
    this.city,
    this.venueName,
    this.address,
    this.latitude,
    this.longitude,
    this.onlinePlatform = 'zoom',
    this.onlineLink,
    this.onlineInstructions,
    this.genderPolicy = 'mixed',
    this.agePolicy = 'all_ages',
    this.customMinAge,
    this.unlimitedCapacity = true,
    this.capacity,
    this.registrationDeadline,
    this.registrationMode = 'instant',
    this.guidelines = '',
    this.pricingType = 'free',
    this.priceAmount,
    this.currency,
    this.paymentMethod = 'pay_at_venue',
    this.coverImageUrl,
    this.coverImagePreviewBytes,
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
    String? timezone,
    String? countryCode,
    String? countryName,
    String? city,
    String? venueName,
    String? address,
    double? latitude,
    double? longitude,
    String? onlinePlatform,
    String? onlineLink,
    String? onlineInstructions,
    String? genderPolicy,
    String? agePolicy,
    int? customMinAge,
    bool? unlimitedCapacity,
    int? capacity,
    DateTime? registrationDeadline,
    String? registrationMode,
    String? guidelines,
    String? pricingType,
    String? priceAmount,
    String? currency,
    String? paymentMethod,
    String? coverImageUrl,
    Uint8List? coverImagePreviewBytes,
    bool clearCoverImagePreviewBytes = false,
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
      timezone: timezone ?? this.timezone,
      countryCode: countryCode ?? this.countryCode,
      countryName: countryName ?? this.countryName,
      city: city ?? this.city,
      venueName: venueName ?? this.venueName,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      onlinePlatform: onlinePlatform ?? this.onlinePlatform,
      onlineLink: onlineLink ?? this.onlineLink,
      onlineInstructions: onlineInstructions ?? this.onlineInstructions,
      genderPolicy: genderPolicy ?? this.genderPolicy,
      agePolicy: agePolicy ?? this.agePolicy,
      customMinAge: customMinAge ?? this.customMinAge,
      unlimitedCapacity: unlimitedCapacity ?? this.unlimitedCapacity,
      capacity: capacity ?? this.capacity,
      registrationDeadline: registrationDeadline ?? this.registrationDeadline,
      registrationMode: registrationMode ?? this.registrationMode,
      guidelines: guidelines ?? this.guidelines,
      pricingType: pricingType ?? this.pricingType,
      priceAmount: priceAmount ?? this.priceAmount,
      currency: currency ?? this.currency,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      coverImagePreviewBytes: clearCoverImagePreviewBytes
          ? null
          : coverImagePreviewBytes ?? this.coverImagePreviewBytes,
      finalConfirmed: finalConfirmed ?? this.finalConfirmed,
    );
  }

  DateTime get startDateTime => DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
        startTime.hour,
        startTime.minute,
      );

  DateTime? get endDateTime {
    if (endDate == null) return null;
    final time = endTime ?? const TimeOfDay(hour: 17, minute: 0);
    return DateTime(
      endDate!.year,
      endDate!.month,
      endDate!.day,
      time.hour,
      time.minute,
    );
  }

  int? get effectiveMinAge {
    if (agePolicy == '18_plus') return 18;
    if (agePolicy == 'custom') return customMinAge;
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'tags': tags,
      'eventType': eventType,
      'language': language,
      'startDate': startDate.toIso8601String(),
      'startTimeHour': startTime.hour,
      'startTimeMinute': startTime.minute,
      'endDate': endDate?.toIso8601String(),
      'endTimeHour': endTime?.hour,
      'endTimeMinute': endTime?.minute,
      'timezone': timezone,
      'countryCode': countryCode,
      'countryName': countryName,
      'city': city,
      'venueName': venueName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'onlinePlatform': onlinePlatform,
      'onlineLink': onlineLink,
      'onlineInstructions': onlineInstructions,
      'genderPolicy': genderPolicy,
      'agePolicy': agePolicy,
      'customMinAge': customMinAge,
      'unlimitedCapacity': unlimitedCapacity,
      'capacity': capacity,
      'registrationDeadline': registrationDeadline?.toIso8601String(),
      'registrationMode': registrationMode,
      'guidelines': guidelines,
      'pricing_type': pricingType,
      'price_amount': priceAmount,
      'currency': currency,
      'payment_method': paymentMethod,
      'cover_image_url': coverImageUrl,
      'finalConfirmed': finalConfirmed,
    };
  }

  factory CreateEventFormData.fromJson(Map<String, dynamic> json) {
    return CreateEventFormData(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      tags: json['tags'] != null ? List<String>.from(json['tags']) : const [],
      eventType: json['eventType'] ?? 'offline',
      language: json['language'] ?? 'en',
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'])
          : null,
      startTime:
          (json['startTimeHour'] != null && json['startTimeMinute'] != null)
              ? TimeOfDay(
                  hour: json['startTimeHour'], minute: json['startTimeMinute'])
              : const TimeOfDay(hour: 9, minute: 0),
      endDate:
          json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
      endTime: (json['endTimeHour'] != null && json['endTimeMinute'] != null)
          ? TimeOfDay(hour: json['endTimeHour'], minute: json['endTimeMinute'])
          : null,
      timezone: json['timezone'] ?? 'UTC',
      countryCode: json['countryCode'],
      countryName: json['countryName'],
      city: json['city'],
      venueName: json['venueName'],
      address: json['address'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      onlinePlatform: json['onlinePlatform'] ?? 'zoom',
      onlineLink: json['onlineLink'],
      onlineInstructions: json['onlineInstructions'],
      genderPolicy: json['genderPolicy'] ?? 'mixed',
      agePolicy: json['agePolicy'] ?? 'all_ages',
      customMinAge: json['customMinAge'],
      unlimitedCapacity: json['unlimitedCapacity'] ?? true,
      capacity: json['capacity'],
      registrationDeadline: json['registrationDeadline'] != null
          ? DateTime.tryParse(json['registrationDeadline'])
          : null,
      registrationMode: json['registrationMode'] ?? 'instant',
      guidelines: json['guidelines'] as String? ?? '',
      pricingType: json['pricing_type'] as String? ?? 'free',
      priceAmount: json['price_amount'] as String?,
      currency: json['currency'] as String?,
      paymentMethod: json['payment_method'] as String? ?? 'pay_at_venue',
      coverImageUrl: json['cover_image_url'] as String?,
      finalConfirmed: json['finalConfirmed'] ?? false,
    );
  }

  @override
  List<Object?> get props => [
        title,
        description,
        category,
        tags,
        eventType,
        language,
        startDate,
        startTime,
        endDate,
        endTime,
        timezone,
        countryCode,
        countryName,
        city,
        venueName,
        address,
        latitude,
        longitude,
        onlinePlatform,
        onlineLink,
        onlineInstructions,
        genderPolicy,
        agePolicy,
        customMinAge,
        unlimitedCapacity,
        capacity,
        registrationDeadline,
        registrationMode,
        guidelines,
        pricingType,
        priceAmount,
        currency,
        paymentMethod,
        coverImageUrl,
        coverImagePreviewBytes,
        finalConfirmed,
      ];
}

class CreateEventState extends Equatable {
  final int currentStep;
  final String? draftId;
  final CreateEventFormData formData;
  final CreateEventStatus status;
  final String? errorMessage;
  final String? aiDescriptionSuggestion;
  final String? aiCategorySuggestion;
  final String? aiCategoryReason;
  final List<String> aiTagSuggestions;
  final DateTime? lastSavedAt;
  final List<String> categoryOptions;
  final bool categoriesLoading;
  final bool isLocalDraftLoaded;

  CreateEventState({
    this.currentStep = 0,
    this.draftId,
    CreateEventFormData? formData,
    this.status = CreateEventStatus.initial,
    this.errorMessage,
    this.aiDescriptionSuggestion,
    this.aiCategorySuggestion,
    this.aiCategoryReason,
    this.aiTagSuggestions = const [],
    this.lastSavedAt,
    this.categoryOptions = const [],
    this.categoriesLoading = false,
    this.isLocalDraftLoaded = false,
  }) : formData = formData ?? CreateEventFormData();

  CreateEventState copyWith({
    int? currentStep,
    String? draftId,
    CreateEventFormData? formData,
    CreateEventStatus? status,
    String? errorMessage,
    String? aiDescriptionSuggestion,
    String? aiCategorySuggestion,
    String? aiCategoryReason,
    List<String>? aiTagSuggestions,
    DateTime? lastSavedAt,
    List<String>? categoryOptions,
    bool? categoriesLoading,
    bool? isLocalDraftLoaded,
  }) {
    return CreateEventState(
      currentStep: currentStep ?? this.currentStep,
      draftId: draftId ?? this.draftId,
      formData: formData ?? this.formData,
      status: status ?? this.status,
      errorMessage: errorMessage,
      aiDescriptionSuggestion:
          aiDescriptionSuggestion ?? this.aiDescriptionSuggestion,
      aiCategorySuggestion: aiCategorySuggestion ?? this.aiCategorySuggestion,
      aiCategoryReason: aiCategoryReason ?? this.aiCategoryReason,
      aiTagSuggestions: aiTagSuggestions ?? this.aiTagSuggestions,
      lastSavedAt: lastSavedAt ?? this.lastSavedAt,
      categoryOptions: categoryOptions ?? this.categoryOptions,
      categoriesLoading: categoriesLoading ?? this.categoriesLoading,
      isLocalDraftLoaded: isLocalDraftLoaded ?? this.isLocalDraftLoaded,
    );
  }

  bool get isFirstStep => currentStep == 0;
  bool get isLastStep => currentStep == 4;

  @override
  List<Object?> get props => [
        currentStep,
        draftId,
        formData,
        status,
        errorMessage,
        aiDescriptionSuggestion,
        aiCategorySuggestion,
        aiCategoryReason,
        aiTagSuggestions,
        lastSavedAt,
        categoryOptions,
        categoriesLoading,
        isLocalDraftLoaded,
      ];
}
