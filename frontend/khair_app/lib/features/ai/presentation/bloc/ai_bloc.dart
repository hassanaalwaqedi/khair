import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/ai_remote_datasource.dart';
import '../../domain/ai_models.dart';

// ---------- Events ----------

abstract class AiEvent extends Equatable {
  const AiEvent();
  @override
  List<Object?> get props => [];
}

class LoadRecommendations extends AiEvent {
  final int limit;
  const LoadRecommendations({this.limit = 10});
  @override
  List<Object?> get props => [limit];
}

class TrackInteraction extends AiEvent {
  final String? eventId;
  final String interactionType;
  final Map<String, dynamic>? metadata;

  const TrackInteraction({
    this.eventId,
    required this.interactionType,
    this.metadata,
  });

  @override
  List<Object?> get props => [eventId, interactionType];
}

class SmartSearchRequested extends AiEvent {
  final String query;
  const SmartSearchRequested(this.query);
  @override
  List<Object?> get props => [query];
}

class EnhanceDescriptionRequested extends AiEvent {
  final String title;
  final String description;
  final List<String>? tags;

  const EnhanceDescriptionRequested({
    required this.title,
    required this.description,
    this.tags,
  });

  @override
  List<Object?> get props => [title, description];
}

class DetectCategoryRequested extends AiEvent {
  final String title;
  final String description;

  const DetectCategoryRequested({
    required this.title,
    required this.description,
  });

  @override
  List<Object?> get props => [title, description];
}

// ---------- State ----------

enum AiStatus { initial, loading, loaded, error }

class AiState extends Equatable {
  final AiStatus recommendationsStatus;
  final List<EventRecommendation> recommendations;
  final bool aiAvailable;
  
  final AiStatus searchStatus;
  final List<String> smartSearchMatchedIds;

  final AiStatus enhanceStatus;
  final EnhancedDescription? enhancedDescription;

  final AiStatus categoryStatus;
  final CategoryDetection? categoryDetection;

  final String? errorMessage;

  const AiState({
    this.recommendationsStatus = AiStatus.initial,
    this.recommendations = const [],
    this.aiAvailable = false,
    this.searchStatus = AiStatus.initial,
    this.smartSearchMatchedIds = const [],
    this.enhanceStatus = AiStatus.initial,
    this.enhancedDescription,
    this.categoryStatus = AiStatus.initial,
    this.categoryDetection,
    this.errorMessage,
  });

  AiState copyWith({
    AiStatus? recommendationsStatus,
    List<EventRecommendation>? recommendations,
    bool? aiAvailable,
    AiStatus? searchStatus,
    List<String>? smartSearchMatchedIds,
    AiStatus? enhanceStatus,
    EnhancedDescription? enhancedDescription,
    AiStatus? categoryStatus,
    CategoryDetection? categoryDetection,
    String? errorMessage,
  }) {
    return AiState(
      recommendationsStatus: recommendationsStatus ?? this.recommendationsStatus,
      recommendations: recommendations ?? this.recommendations,
      aiAvailable: aiAvailable ?? this.aiAvailable,
      searchStatus: searchStatus ?? this.searchStatus,
      smartSearchMatchedIds: smartSearchMatchedIds ?? this.smartSearchMatchedIds,
      enhanceStatus: enhanceStatus ?? this.enhanceStatus,
      enhancedDescription: enhancedDescription ?? this.enhancedDescription,
      categoryStatus: categoryStatus ?? this.categoryStatus,
      categoryDetection: categoryDetection ?? this.categoryDetection,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        recommendationsStatus,
        recommendations,
        aiAvailable,
        searchStatus,
        smartSearchMatchedIds,
        enhanceStatus,
        enhancedDescription,
        categoryStatus,
        categoryDetection,
        errorMessage,
      ];
}

// ---------- BLoC ----------

class AiBloc extends Bloc<AiEvent, AiState> {
  final AiRemoteDataSource _dataSource;

  AiBloc(this._dataSource) : super(const AiState()) {
    on<LoadRecommendations>(_onLoadRecommendations);
    on<TrackInteraction>(_onTrackInteraction);
    on<SmartSearchRequested>(_onSmartSearch);
    on<EnhanceDescriptionRequested>(_onEnhanceDescription);
    on<DetectCategoryRequested>(_onDetectCategory);
  }

  Future<void> _onLoadRecommendations(
    LoadRecommendations event,
    Emitter<AiState> emit,
  ) async {
    emit(state.copyWith(recommendationsStatus: AiStatus.loading));
    try {
      final data = await _dataSource.getRecommendations(limit: event.limit);
      final aiAvailable = data['ai_available'] as bool? ?? false;
      final recList = data['recommendations'] as List? ?? [];

      final recommendations = recList
          .map((e) => EventRecommendation.fromJson(e as Map<String, dynamic>))
          .toList();

      emit(state.copyWith(
        recommendationsStatus: AiStatus.loaded,
        recommendations: recommendations,
        aiAvailable: aiAvailable,
      ));
    } catch (e) {
      emit(state.copyWith(
        recommendationsStatus: AiStatus.error,
        errorMessage: e.toString(),
        aiAvailable: false,
      ));
    }
  }

  Future<void> _onTrackInteraction(
    TrackInteraction event,
    Emitter<AiState> emit,
  ) async {
    // Fire-and-forget — never blocks UI
    _dataSource.logInteraction(
      eventId: event.eventId,
      interactionType: event.interactionType,
      metadata: event.metadata,
    );
  }

  Future<void> _onSmartSearch(
    SmartSearchRequested event,
    Emitter<AiState> emit,
  ) async {
    emit(state.copyWith(searchStatus: AiStatus.loading));
    try {
      final data = await _dataSource.smartSearch(event.query);
      final ids = (data['matched_ids'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [];
      emit(state.copyWith(
        searchStatus: AiStatus.loaded,
        smartSearchMatchedIds: ids,
      ));
    } catch (e) {
      emit(state.copyWith(
        searchStatus: AiStatus.error,
        smartSearchMatchedIds: [],
      ));
    }
  }

  Future<void> _onEnhanceDescription(
    EnhanceDescriptionRequested event,
    Emitter<AiState> emit,
  ) async {
    emit(state.copyWith(enhanceStatus: AiStatus.loading));
    try {
      final data = await _dataSource.enhanceDescription(
        title: event.title,
        description: event.description,
        tags: event.tags,
      );
      emit(state.copyWith(
        enhanceStatus: AiStatus.loaded,
        enhancedDescription: EnhancedDescription.fromJson(data),
      ));
    } catch (e) {
      emit(state.copyWith(
        enhanceStatus: AiStatus.error,
        errorMessage: 'AI enhancement unavailable',
      ));
    }
  }

  Future<void> _onDetectCategory(
    DetectCategoryRequested event,
    Emitter<AiState> emit,
  ) async {
    emit(state.copyWith(categoryStatus: AiStatus.loading));
    try {
      final data = await _dataSource.detectCategory(
        title: event.title,
        description: event.description,
      );
      emit(state.copyWith(
        categoryStatus: AiStatus.loaded,
        categoryDetection: CategoryDetection.fromJson(data),
      ));
    } catch (e) {
      emit(state.copyWith(
        categoryStatus: AiStatus.error,
        errorMessage: 'AI category detection unavailable',
      ));
    }
  }
}
