import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../events/domain/repositories/events_repository.dart';
import 'create_event_state.dart';

/// Cubit for the Create Event wizard.
/// No navigation logic — emits states, UI listens and navigates.
class CreateEventCubit extends Cubit<CreateEventState> {
  final EventsRepository _eventsRepository;

  CreateEventCubit(this._eventsRepository) : super(CreateEventState());

  // ── Step Navigation ──

  void goToStep(int step) {
    if (step < 0 || step > 4) return;
    emit(state.copyWith(
      currentStep: step,
      status: CreateEventStatus.initial,
    ));
  }

  void nextStep() {
    if (!state.isLastStep) goToStep(state.currentStep + 1);
  }

  void previousStep() {
    if (!state.isFirstStep) goToStep(state.currentStep - 1);
  }

  // ── Form Data Updates ──

  void updateFormData(CreateEventFormData formData) {
    emit(state.copyWith(formData: formData));
  }

  void updateTitle(String title) {
    emit(state.copyWith(formData: state.formData.copyWith(title: title)));
  }

  void updateDescription(String description) {
    emit(state.copyWith(formData: state.formData.copyWith(description: description)));
  }

  void updateCategory(String category) {
    emit(state.copyWith(formData: state.formData.copyWith(category: category)));
  }

  void toggleTag(String tag) {
    final tags = List<String>.from(state.formData.tags);
    tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
    emit(state.copyWith(formData: state.formData.copyWith(tags: tags)));
  }

  void updateEventType(String type) {
    emit(state.copyWith(formData: state.formData.copyWith(eventType: type)));
  }

  void updateLanguage(String language) {
    emit(state.copyWith(formData: state.formData.copyWith(language: language)));
  }

  void updateCompliance(ComplianceSettings compliance) {
    emit(state.copyWith(formData: state.formData.copyWith(compliance: compliance)));
  }

  void updateCoverImage(String url) {
    emit(state.copyWith(
      formData: state.formData.copyWith(coverImageUrl: url),
      status: CreateEventStatus.initial,
    ));
  }

  void setFinalConfirmed(bool confirmed) {
    emit(state.copyWith(formData: state.formData.copyWith(finalConfirmed: confirmed)));
  }

  // ── Step Validation ──

  bool validateStep(int step) {
    final fd = state.formData;
    switch (step) {
      case 0: // Basic Info
        return fd.title.trim().length >= 3 &&
            fd.description.trim().length >= 50 &&
            fd.category.isNotEmpty;
      case 1: // Location
        if (fd.eventType == 'offline') {
          return fd.countryCode != null &&
              fd.city != null &&
              fd.city!.isNotEmpty;
        } else {
          return fd.onlinePlatform != null &&
              fd.onlineLink != null &&
              fd.onlineLink!.isNotEmpty;
        }
      case 2: // Compliance
        return fd.compliance.enabledCount >= 2 &&
            fd.compliance.complianceConfirmed;
      case 3: // Media
        return fd.coverImageUrl != null && fd.coverImageUrl!.isNotEmpty;
      case 4: // Review
        return fd.finalConfirmed;
      default:
        return true;
    }
  }

  bool get isCurrentStepValid => validateStep(state.currentStep);

  // ── Submit Event ──

  Future<void> submitEvent() async {
    if (!state.formData.finalConfirmed) {
      emit(state.copyWith(
        status: CreateEventStatus.failure,
        errorMessage: 'Please confirm the final review checkbox.',
      ));
      return;
    }

    emit(state.copyWith(status: CreateEventStatus.submitting));

    final fd = state.formData;
    final params = CreateEventParams(
      title: fd.title.trim(),
      description: fd.description.trim().isEmpty ? null : fd.description.trim(),
      eventType: fd.eventType,
      language: fd.language,
      country: fd.eventType == 'offline' ? fd.countryCode : null,
      city: fd.eventType == 'offline' ? fd.city : null,
      address: fd.eventType == 'offline' ? fd.address : null,
      startDate: fd.startDateTime,
      endDate: fd.endDateTime,
      imageUrl: fd.coverImageUrl,
    );

    final result = await _eventsRepository.createEvent(params);

    result.fold(
      (failure) => emit(state.copyWith(
        status: CreateEventStatus.failure,
        errorMessage: failure.message,
      )),
      (event) => emit(state.copyWith(
        status: CreateEventStatus.success,
      )),
    );
  }

  // ── Save Draft ──

  void saveDraft() {
    // For now, emit draft saved state.
    // In production: persist to SharedPreferences or call backend draft endpoint.
    emit(state.copyWith(status: CreateEventStatus.draftSaved));
  }

  // ── Image Upload (placeholder — real upload needs multipart endpoint) ──

  Future<void> uploadImage(String filePath) async {
    emit(state.copyWith(status: CreateEventStatus.imageUploading));

    try {
      // TODO: Replace with real multipart upload to backend
      // For now, store the local file path as the URL
      await Future.delayed(const Duration(milliseconds: 500));
      emit(state.copyWith(
        formData: state.formData.copyWith(coverImageUrl: filePath),
        status: CreateEventStatus.initial,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CreateEventStatus.failure,
        errorMessage: 'Image upload failed: $e',
      ));
    }
  }
}
