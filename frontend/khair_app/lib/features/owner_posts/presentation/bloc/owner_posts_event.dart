part of 'owner_posts_bloc.dart';

abstract class OwnerPostsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadActivePosts extends OwnerPostsEvent {}

class LoadAllPosts extends OwnerPostsEvent {}

class CreateOwnerPost extends OwnerPostsEvent {
  final String title;
  final String shortDescription;
  final String? imageUrl;
  final String? externalLink;
  final String? location;

  CreateOwnerPost({
    required this.title,
    required this.shortDescription,
    this.imageUrl,
    this.externalLink,
    this.location,
  });

  @override
  List<Object?> get props =>
      [title, shortDescription, imageUrl, externalLink, location];
}

class UpdateOwnerPost extends OwnerPostsEvent {
  final String id;
  final Map<String, dynamic> data;
  UpdateOwnerPost({required this.id, required this.data});

  @override
  List<Object?> get props => [id, data];
}

class DeleteOwnerPost extends OwnerPostsEvent {
  final String id;
  DeleteOwnerPost(this.id);

  @override
  List<Object?> get props => [id];
}
