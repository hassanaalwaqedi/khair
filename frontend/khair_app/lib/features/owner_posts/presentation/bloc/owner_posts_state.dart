part of 'owner_posts_bloc.dart';

enum OwnerPostsStatus { initial, loading, success, failure }

class OwnerPostsState extends Equatable {
  final OwnerPostsStatus status;
  final OwnerPostsStatus formStatus;
  final List<OwnerPost> activePosts;
  final List<OwnerPost> allPosts;
  final String? errorMessage;

  const OwnerPostsState({
    this.status = OwnerPostsStatus.initial,
    this.formStatus = OwnerPostsStatus.initial,
    this.activePosts = const [],
    this.allPosts = const [],
    this.errorMessage,
  });

  OwnerPostsState copyWith({
    OwnerPostsStatus? status,
    OwnerPostsStatus? formStatus,
    List<OwnerPost>? activePosts,
    List<OwnerPost>? allPosts,
    String? errorMessage,
  }) {
    return OwnerPostsState(
      status: status ?? this.status,
      formStatus: formStatus ?? this.formStatus,
      activePosts: activePosts ?? this.activePosts,
      allPosts: allPosts ?? this.allPosts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, formStatus, activePosts, allPosts, errorMessage];
}
