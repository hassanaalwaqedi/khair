import '../../domain/entities/owner_post.dart';
import '../../domain/repositories/owner_post_repository.dart';
import '../datasources/owner_post_remote_datasource.dart';

class OwnerPostRepositoryImpl implements OwnerPostRepository {
  final OwnerPostRemoteDataSource _remote;
  OwnerPostRepositoryImpl(this._remote);

  @override
  Future<List<OwnerPost>> getActivePosts() => _remote.getActivePosts();

  @override
  Future<List<OwnerPost>> getAllPosts() => _remote.getAllPosts();

  @override
  Future<OwnerPost> createPost({
    required String title,
    required String shortDescription,
    String? imageUrl,
    String? externalLink,
    String? location,
  }) {
    return _remote.createPost({
      'title': title,
      'short_description': shortDescription,
      if (imageUrl != null) 'image_url': imageUrl,
      if (externalLink != null) 'external_link': externalLink,
      if (location != null) 'location': location,
    });
  }

  @override
  Future<OwnerPost> updatePost(String id, Map<String, dynamic> data) =>
      _remote.updatePost(id, data);

  @override
  Future<void> deletePost(String id) => _remote.deletePost(id);
}
