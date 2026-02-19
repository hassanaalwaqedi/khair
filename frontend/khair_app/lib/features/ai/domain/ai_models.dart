import 'package:equatable/equatable.dart';

/// Represents an AI event recommendation score
class EventRecommendation extends Equatable {
  final String eventId;
  final double relevanceScore;
  final String reasoning;

  const EventRecommendation({
    required this.eventId,
    required this.relevanceScore,
    this.reasoning = '',
  });

  factory EventRecommendation.fromJson(Map<String, dynamic> json) {
    return EventRecommendation(
      eventId: json['event_id'] as String,
      relevanceScore: (json['relevance_score'] as num).toDouble(),
      reasoning: json['reasoning'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [eventId, relevanceScore];
}

/// Represents an AI-enhanced description result
class EnhancedDescription {
  final String title;
  final String description;
  final String shortSummary;
  final List<String> suggestedTags;
  final List<String> missingDetails;

  const EnhancedDescription({
    required this.title,
    required this.description,
    required this.shortSummary,
    required this.suggestedTags,
    required this.missingDetails,
  });

  factory EnhancedDescription.fromJson(Map<String, dynamic> json) {
    return EnhancedDescription(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      shortSummary: json['short_summary'] as String? ?? '',
      suggestedTags: (json['suggested_tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      missingDetails: (json['missing_details'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

/// Represents an AI category detection result
class CategoryDetection {
  final String category;
  final double confidence;
  final List<String> tags;
  final String reasoning;

  const CategoryDetection({
    required this.category,
    required this.confidence,
    required this.tags,
    required this.reasoning,
  });

  factory CategoryDetection.fromJson(Map<String, dynamic> json) {
    return CategoryDetection(
      category: json['category'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      reasoning: json['reasoning'] as String? ?? '',
    );
  }
}
