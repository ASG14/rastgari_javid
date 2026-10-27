import 'package:backend/src/features/posts/data/post_repository.dart';

/// Handles application operations related to posts.
class PostService {
  /// Creates a service using the provided post repository.
  PostService(this._postRepository);

  final PostRepository _postRepository;

  /// Returns the latest public posts.
  Future<List<Map<String, dynamic>>> getPublicPosts() {
    return _postRepository.getPublicPosts();
  }
}
