import '../../../../core/network/api_client.dart';
import '../models/owner_post_model.dart';

class OwnerPostRemoteDataSource {
  final ApiClient _api;
  OwnerPostRemoteDataSource(this._api);

  /// Public: get active posts
  Future<List<OwnerPostModel>> getActivePosts() async {
    final response = await _api.get('/owner-posts');
    final data = response.data['data'] as List? ?? [];
    return data
        .map((e) => OwnerPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Admin: get all posts
  Future<List<OwnerPostModel>> getAllPosts() async {
    final response = await _api.get('/owner/posts');
    final data = response.data['data'] as List? ?? [];
    return data
        .map((e) => OwnerPostModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Admin: create post
  Future<OwnerPostModel> createPost(Map<String, dynamic> body) async {
    final response = await _api.post('/owner/posts', data: body);
    return OwnerPostModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Admin: update post
  Future<OwnerPostModel> updatePost(String id, Map<String, dynamic> body) async {
    final response = await _api.put('/owner/posts/$id', data: body);
    return OwnerPostModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  /// Admin: delete post
  Future<void> deletePost(String id) async {
    await _api.delete('/owner/posts/$id');
  }
}
