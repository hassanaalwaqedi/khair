import '../../domain/entities/owner_post.dart';

class OwnerPostModel extends OwnerPost {
  const OwnerPostModel({
    required super.id,
    required super.title,
    required super.shortDescription,
    super.imageUrl,
    super.externalLink,
    super.location,
    required super.publishedAt,
    required super.createdBy,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
  });

  factory OwnerPostModel.fromJson(Map<String, dynamic> json) {
    return OwnerPostModel(
      id: json['id'] as String,
      title: json['title'] as String,
      shortDescription: json['short_description'] as String,
      imageUrl: json['image_url'] as String?,
      externalLink: json['external_link'] as String?,
      location: json['location'] as String?,
      publishedAt: DateTime.parse(json['published_at'] as String),
      createdBy: json['created_by'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'short_description': shortDescription,
        'image_url': imageUrl,
        'external_link': externalLink,
        'location': location,
        'published_at': publishedAt.toIso8601String(),
        'created_by': createdBy,
        'is_active': isActive,
      };
}
