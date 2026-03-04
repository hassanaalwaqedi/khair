import 'package:equatable/equatable.dart';

class OwnerPost extends Equatable {
  final String id;
  final String title;
  final String shortDescription;
  final String? imageUrl;
  final String? externalLink;
  final String? location;
  final DateTime publishedAt;
  final String createdBy;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OwnerPost({
    required this.id,
    required this.title,
    required this.shortDescription,
    this.imageUrl,
    this.externalLink,
    this.location,
    required this.publishedAt,
    required this.createdBy,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        shortDescription,
        imageUrl,
        externalLink,
        location,
        publishedAt,
        createdBy,
        isActive,
        createdAt,
        updatedAt,
      ];
}
