import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/di/injection.dart';
import '../../../events/domain/repositories/events_repository.dart';
import 'create_event_state.dart';

class CreateEventCubit extends Cubit<CreateEventState> {
  final EventsRepository _eventsRepository;
  Timer? _autosaveTimer;
  static const String _draftCacheKey = 'create_event_draft_cache';

  CreateEventCubit(this._eventsRepository) : super(CreateEventState());

  Future<void> loadLocalDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString(_draftCacheKey);
      if (draftStr != null && draftStr.isNotEmpty) {
        final Map<String, dynamic> json = jsonDecode(draftStr);
        final formData = CreateEventFormData.fromJson(json);
        emit(state.copyWith(
          formData: formData,
          status: CreateEventStatus.initial,
          isLocalDraftLoaded: true,
        ));
      } else {
        emit(state.copyWith(isLocalDraftLoaded: true));
      }
    } catch (e) {
      // Ignore parse errors, just start fresh
      emit(state.copyWith(isLocalDraftLoaded: true));
    }
  }

  Future<void> clearLocalDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftCacheKey);
  }

  Future<void> loadCategories() async {
    emit(state.copyWith(categoriesLoading: true));
    try {
      final response = await getIt<Dio>().get('/discover/categories');
      final raw = response.data['data'];
      final values = raw is List
          ? raw
              .whereType<Map>()
              .map((item) => item['name']?.toString().trim().toLowerCase())
              .whereType<String>()
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
          : <String>[];
      emit(state.copyWith(
        categoriesLoading: false,
        categoryOptions: values,
      ));
    } on DioException {
      emit(state.copyWith(categoriesLoading: false));
    }
  }

  void goToStep(int step) {
    if (step < 0 || step > 4) return;
    emit(state.copyWith(currentStep: step, status: CreateEventStatus.initial));
  }

  bool nextStep() {
    if (!validateStep(state.currentStep)) return false;
    if (!state.isLastStep) goToStep(state.currentStep + 1);
    return true;
  }

  void previousStep() {
    if (!state.isFirstStep) goToStep(state.currentStep - 1);
  }

  void updateFormData(CreateEventFormData formData) {
    emit(state.copyWith(formData: formData, status: CreateEventStatus.initial));
    _scheduleAutosave();
  }

  void updateTitle(String value) =>
      _update(state.formData.copyWith(title: value));
  void updateDescription(String value) =>
      _update(state.formData.copyWith(description: value));
  void updateCategory(String value) =>
      _update(state.formData.copyWith(category: value));
  void updateEventType(String value) =>
      _update(state.formData.copyWith(eventType: value));
  void updateLanguage(String value) =>
      _update(state.formData.copyWith(language: value));
  void updateGenderPolicy(String value) =>
      _update(state.formData.copyWith(genderPolicy: value));
  void updateAgePolicy(String value) =>
      _update(state.formData.copyWith(agePolicy: value));
  void updateCapacity({required bool unlimited, int? value}) => _update(
        state.formData.copyWith(unlimitedCapacity: unlimited, capacity: value),
      );
  void updateRegistrationMode(String value) =>
      _update(state.formData.copyWith(registrationMode: value));
  void setFinalConfirmed(bool value) =>
      _update(state.formData.copyWith(finalConfirmed: value));

  void addTag(String rawTag) {
    final tag = rawTag.trim().replaceFirst(RegExp(r'^#'), '');
    if (tag.isEmpty || tag.length > 32 || state.formData.tags.length >= 8)
      return;
    if (!RegExp(r'^[\p{L}\p{N} _-]+$', unicode: true).hasMatch(tag)) return;
    if (state.formData.tags
        .any((item) => item.toLowerCase() == tag.toLowerCase())) {
      return;
    }
    _update(state.formData.copyWith(tags: [...state.formData.tags, tag]));
  }

  void removeTag(String tag) => _update(
        state.formData.copyWith(
          tags: state.formData.tags.where((item) => item != tag).toList(),
        ),
      );

  void useCategorySuggestion() {
    final suggestion = state.aiCategorySuggestion;
    if (suggestion == null || suggestion.isEmpty) return;
    emit(state.copyWith(
      formData: state.formData.copyWith(category: suggestion),
      aiCategorySuggestion: '',
    ));
    _scheduleAutosave();
  }

  void useDescriptionSuggestion() {
    final suggestion = state.aiDescriptionSuggestion;
    if (suggestion == null || suggestion.isEmpty) return;
    emit(state.copyWith(
      formData: state.formData.copyWith(description: suggestion),
      aiDescriptionSuggestion: '',
    ));
    _scheduleAutosave();
  }

  void useSuggestedTag(String tag) {
    addTag(tag);
    emit(state.copyWith(
      aiTagSuggestions:
          state.aiTagSuggestions.where((item) => item != tag).toList(),
    ));
  }

  bool validateStep(int step) {
    final fd = state.formData;
    switch (step) {
      case 0:
        return fd.title.trim().length >= 3 &&
            fd.title.trim().length <= 120 &&
            fd.description.trim().length >= 50 &&
            fd.category.trim().isNotEmpty;
      case 1:
        if (fd.startDateTime.isBefore(DateTime.now())) return false;
        if (fd.endDateTime != null &&
            !fd.endDateTime!.isAfter(fd.startDateTime)) {
          return false;
        }
        if (fd.eventType == 'online') {
          return fd.onlinePlatform != null &&
              fd.onlinePlatform!.isNotEmpty &&
              _isValidUrl(fd.onlineLink);
        }
        return fd.countryCode != null &&
            fd.city?.trim().isNotEmpty == true &&
            fd.address?.trim().isNotEmpty == true &&
            fd.latitude != null &&
            fd.longitude != null;
      case 2:
        return fd.genderPolicy.isNotEmpty &&
            (fd.unlimitedCapacity || (fd.capacity ?? 0) > 0) &&
            (fd.registrationDeadline == null ||
                fd.registrationDeadline!.isBefore(fd.startDateTime));
      case 3:
        return fd.coverImageUrl?.isNotEmpty == true;
      case 4:
        return fd.finalConfirmed && [0, 1, 2, 3].every(validateStep);
      default:
        return false;
    }
  }

  String validationMessage(int step) {
    final fd = state.formData;
    switch (step) {
      case 0:
        if (fd.title.trim().length < 3) return 'Add an event title.';
        if (fd.description.trim().length < 50) {
          return 'Description must be at least 50 characters.';
        }
        return 'Choose a category.';
      case 1:
        if (fd.startDateTime.isBefore(DateTime.now())) {
          return 'Start date and time must be in the future.';
        }
        if (fd.endDateTime != null && !fd.endDateTime!.isAfter(fd.startDateTime)) {
          return 'End date and time must be after the start date.';
        }
        if (fd.eventType == 'online') return 'Add a valid meeting URL.';
        if (fd.countryCode == null) return 'Select a country.';
        if (fd.city?.trim().isEmpty ?? true) return 'Enter a city.';
        if (fd.address?.trim().isEmpty ?? true) return 'Enter a street address.';
        if (fd.latitude == null || fd.longitude == null) return 'Pinpoint the exact location on the map.';
        return 'Complete all required fields.';
      case 2:
        return fd.unlimitedCapacity
            ? 'Choose who the event is for.'
            : 'Add a positive attendee capacity.';
      case 3:
        return 'Add a cover image before continuing.';
      case 4:
        return 'Confirm that the event details are ready to submit.';
      default:
        return 'Complete the required fields.';
    }
  }

  bool get isCurrentStepValid => validateStep(state.currentStep);

  Future<void> suggestCategory() async {
    if (state.formData.title.trim().isEmpty) return;
    emit(state.copyWith(status: CreateEventStatus.aiGenerating));
    try {
      final response = await getIt<Dio>().post('/ai/detect-category', data: {
        'title': state.formData.title.trim(),
        'description': state.formData.description.trim(),
      });
      final data = response.data['data'];
      emit(state.copyWith(
        status: CreateEventStatus.initial,
        aiCategorySuggestion: data?['category']?.toString(),
        aiCategoryReason: data?['reason']?.toString(),
      ));
    } on DioException catch (error) {
      emit(state.copyWith(
        status: CreateEventStatus.failure,
        errorMessage:
            _friendlyError(error, 'Category suggestion is unavailable.'),
      ));
    }
  }

  Future<void> suggestDescription() async {
    if (state.formData.title.trim().isEmpty) return;
    emit(state.copyWith(status: CreateEventStatus.aiGenerating));
    try {
      final response =
          await getIt<Dio>().post('/ai/enhance-description', data: {
        'title': state.formData.title.trim(),
        'description': state.formData.description.trim(),
        'category': state.formData.category,
        'event_type': state.formData.eventType,
        'language': state.formData.language,
        'city': state.formData.city,
        'audience': state.formData.genderPolicy,
        'tags': state.formData.tags,
      });
      final data = response.data['data'];
      final suggestion = data?['description']?.toString();
      final suggestedTags = data?['suggested_tags'] is List
          ? List<String>.from(data['suggested_tags'])
          : <String>[];
      emit(state.copyWith(
        status: CreateEventStatus.initial,
        aiDescriptionSuggestion: suggestion,
        aiTagSuggestions: suggestedTags,
      ));
    } on DioException catch (error) {
      emit(state.copyWith(
        status: CreateEventStatus.failure,
        errorMessage:
            _friendlyError(error, 'Khair AI is unavailable right now.'),
      ));
    }
  }

  Future<void> uploadImage(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw Exception('The selected image is empty.');

      // Show the selected image immediately. The permanent URL is still
      // required before the draft can be submitted.
      emit(state.copyWith(
        status: CreateEventStatus.imageUploading,
        formData: state.formData.copyWith(coverImagePreviewBytes: bytes),
      ));

      final response = await getIt<Dio>().post(
        '/upload/image',
        data: FormData.fromMap({
          'image': MultipartFile.fromBytes(bytes, filename: file.name),
        }),
      );
      final url = response.data['data']?['url']?.toString();
      if (url == null || url.isEmpty)
        throw Exception('No permanent image URL returned.');
      _update(state.formData.copyWith(coverImageUrl: url), schedule: false);
    } on DioException catch (error) {
      emit(state.copyWith(
        status: CreateEventStatus.failure,
        errorMessage:
            _friendlyError(error, 'Image upload failed. Try another image.'),
      ));
    } catch (_) {
      emit(state.copyWith(
        status: CreateEventStatus.failure,
        errorMessage: 'Image upload failed. Try another image.',
      ));
    }
  }

  Future<void> saveDraft({bool redirectAfterSave = false}) async {
    await _persistDraft(redirectAfterSave: redirectAfterSave);
  }

  Future<void> submitEvent() async {
    if (!validateStep(4)) {
      emit(state.copyWith(
        status: CreateEventStatus.failure,
        errorMessage: validationMessage(state.currentStep),
      ));
      return;
    }
    emit(state.copyWith(status: CreateEventStatus.submitting));
    final draft = await _persistDraft(emitSavedState: false);
    if (draft == null || isClosed) return;
    final result = await _eventsRepository.submitForReview(draft.id);
    result.fold(
      (failure) => emit(state.copyWith(
        status: CreateEventStatus.failure,
        errorMessage: _cleanMessage(failure.message),
      )),
      (_) async {
        await clearLocalDraft();
        emit(state.copyWith(status: CreateEventStatus.success));
      },
    );
  }

  Future<void> disposeAutosave() async {
    _autosaveTimer?.cancel();
    if (state.formData.title.trim().isNotEmpty) await _persistDraft();
  }


  Future<dynamic> _persistDraft({
    bool redirectAfterSave = false,
    bool emitSavedState = true,
  }) async {
    final fd = state.formData;
    if (fd.title.trim().isEmpty) return null;
    if (emitSavedState) emit(state.copyWith(status: CreateEventStatus.saving));
    final params = _params(fd);
    final result = state.draftId == null
        ? await _eventsRepository.createDraft(params)
        : await _eventsRepository.updateEvent(
            state.draftId!, params.toUpdateParams());
    return result.fold(
      (failure) {
        if (emitSavedState) {
          emit(state.copyWith(
            status: CreateEventStatus.failure,
            errorMessage: _cleanMessage(failure.message),
          ));
        }
        return null;
      },
      (event) {
        emit(state.copyWith(
          draftId: event.id,
          status: emitSavedState
              ? CreateEventStatus.saved
              : CreateEventStatus.submitting,
          lastSavedAt: DateTime.now(),
        ));
        return event;
      },
    );
  }

  CreateEventParams _params(CreateEventFormData fd) => CreateEventParams(
        title: fd.title.trim(),
        description: fd.description.trim(),
        category: fd.category.trim(),
        tags: fd.tags,
        eventType: fd.eventType.trim(),
        language: fd.language,
        country: fd.eventType == 'offline' ? fd.countryCode : null,
        city: fd.eventType == 'offline' ? fd.city : null,
        venueName: fd.eventType == 'offline' ? fd.venueName : null,
        address: fd.eventType == 'offline' ? fd.address : null,
        latitude: fd.eventType == 'offline' ? fd.latitude : null,
        longitude: fd.eventType == 'offline' ? fd.longitude : null,
        startDate: fd.startDateTime,
        endDate: fd.endDateTime,
        imageUrl: fd.coverImageUrl,
        ticketPrice: null,
        currency: null,
        isOnline: fd.eventType == 'online',
        onlinePlatform: fd.onlinePlatform,
        onlineLink: fd.eventType == 'online' ? fd.onlineLink : null,
        joinInstructions:
            fd.eventType == 'online' ? fd.onlineInstructions : null,
        capacity: fd.unlimitedCapacity ? null : fd.capacity,
        genderRestriction: fd.genderPolicy,
        ageMin: fd.effectiveMinAge,
        registrationDeadline: fd.registrationDeadline,
        registrationMode: fd.registrationMode,
        timezone: fd.timezone,
        guidelines: fd.guidelines.trim().isEmpty ? null : fd.guidelines.trim(),
      );

  void _update(CreateEventFormData data, {bool schedule = true}) {
    emit(state.copyWith(formData: data, status: CreateEventStatus.initial));
    if (schedule) _scheduleAutosave();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    
    // Save locally immediately without debouncing
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_draftCacheKey, jsonEncode(state.formData.toJson()));
    });

    _autosaveTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!isClosed && state.formData.title.trim().isNotEmpty) {
        _persistDraft();
      }
    });
  }

  bool _isValidUrl(String? value) {
    final uri = Uri.tryParse(value ?? '');
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  String _friendlyError(DioException error, String fallback) {
    final response = error.response?.data;
    if (response is Map && response['error'] is String)
      return response['error'] as String;
    return fallback;
  }

  String _cleanMessage(String message) {
    if (message.contains('DioException') || message.contains('Exception')) {
      return 'We could not save this event. Check your connection and try again.';
    }
    return message;
  }

  @override
  Future<void> close() async {
    _autosaveTimer?.cancel();
    super.close();
  }
}
