import '../entities/owner_post.dart';

abstract class OwnerPostRepository {
  Future<List<OwnerPost>> getActivePosts();
  Future<List<OwnerPost>> getAllPosts();
  Future<OwnerPost> createPost({
    required String title,
    required String shortDescription,
    String? imageUrl,
    String? externalLink,
    String? location,
  });
  Future<OwnerPost> updatePost(String id, Map<String, dynamic> data);
  Future<void> deletePost(String id);
}
