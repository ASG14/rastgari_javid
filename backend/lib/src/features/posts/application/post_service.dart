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

  /// Publishes a public post for the authenticated user.
  Future<Map<String, dynamic>> createPublicPost({
    required int userId,
    required String content,
  }) async {
    final normalizedContent = content.trim();

    if (normalizedContent.isEmpty) {
      throw const PostException('متن پست نمی‌تواند خالی باشد.');
    }

    if (normalizedContent.length > 10000) {
      throw const PostException(
        'متن پست نمی‌تواند بیشتر از ۱۰۰۰۰ کاراکتر باشد.',
      );
    }

    return _postRepository.createPublicPost(
      userId: userId,
      content: normalizedContent,
    );
  }
}

/// Represents a post-related validation error.
class PostException implements Exception {
  /// Creates a post exception with a user-facing message.
  const PostException(this.message);

  /// The validation message.
  final String message;

  @override
  String toString() => message;
}
