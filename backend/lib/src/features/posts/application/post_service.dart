import 'dart:convert';

import 'package:backend/src/features/posts/data/post_repository.dart';

/// Handles application operations related to posts.
class PostService {
  /// Creates a service using the provided post repository.
  PostService(this._postRepository);

  final PostRepository _postRepository;

  /// Returns a paginated list of posts visible to the current user.
  Future<Map<String, dynamic>> getPublicPosts({
    int? currentUserId,
    int limit = 20,
    String? cursor,
  }) async {
    if (limit < 1 || limit > 50) {
      throw const PostException(
        'تعداد نوشته‌ها باید بین ۱ تا ۵۰ باشد.',
      );
    }

    int? cursorPostId;
    DateTime? cursorPublishedAt;
    var cursorPublishedAtIsNull = false;

    if (cursor != null) {
      try {
        final normalizedCursor = base64Url.normalize(cursor);
        final decoded = jsonDecode(
          utf8.decode(base64Url.decode(normalizedCursor)),
        );

        if (decoded is! Map<String, dynamic>) {
          throw const FormatException();
        }

        final id = decoded['id'];
        final publishedAt = decoded['published_at'];

        if (id is! int || id < 1) {
          throw const FormatException();
        }

        cursorPostId = id;

        if (publishedAt == null) {
          cursorPublishedAtIsNull = true;
        } else if (publishedAt is String) {
          cursorPublishedAt = DateTime.tryParse(publishedAt);

          if (cursorPublishedAt == null) {
            throw const FormatException();
          }
        } else {
          throw const FormatException();
        }
      } catch (_) {
        throw const PostException(
          'نشانگر صفحه‌بندی معتبر نیست.',
        );
      }
    }

    final rows = await _postRepository.getPublicPosts(
      currentUserId: currentUserId,
      limit: limit,
      cursorPostId: cursorPostId,
      cursorPublishedAt: cursorPublishedAt,
      cursorPublishedAtIsNull: cursorPublishedAtIsNull,
    );

    final hasMore = rows.length > limit;
    final posts = rows.take(limit).toList();

    String? nextCursor;

    if (hasMore && posts.isNotEmpty) {
      final lastPost = posts.last;

      final cursorData = jsonEncode({
        'id': lastPost['id'],
        'published_at': lastPost['published_at'],
      });

      nextCursor = base64Url.encode(utf8.encode(cursorData));
    }

    return {
      'data': posts,
      'pagination': {
        'limit': limit,
        'has_more': hasMore,
        'next_cursor': nextCursor,
      },
    };
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

  /// Sets the like state for an authenticated user.
  Future<Map<String, dynamic>?> setPostLike({
    required int postId,
    required int userId,
    required bool isLiked,
  }) {
    if (postId < 1 || userId < 1) {
      throw const PostException('شناسه پست یا کاربر معتبر نیست.');
    }

    return _postRepository.setPostLike(
      postId: postId,
      userId: userId,
      isLiked: isLiked,
    );
  }

  /// Retrieves a post visible to the current user.
  Future<Map<String, dynamic>?> getPostById({
    required int postId,
    int? currentUserId,
  }) {
    if (postId < 1 || (currentUserId != null && currentUserId < 1)) {
      throw const PostException('شناسه پست یا کاربر معتبر نیست.');
    }

    return _postRepository.getPostById(
      postId: postId,
      currentUserId: currentUserId,
    );
  }

  /// Updates the content of a post owned by the authenticated user.
  Future<Map<String, dynamic>?> updatePost({
    required int postId,
    required int userId,
    required String content,
  }) {
    if (postId < 1 || userId < 1) {
      throw const PostException('شناسه پست یا کاربر معتبر نیست.');
    }

    final normalizedContent = content.trim();

    if (normalizedContent.isEmpty) {
      throw const PostException('متن پست نمی‌تواند خالی باشد.');
    }

    if (normalizedContent.length > 10000) {
      throw const PostException(
        'متن پست نمی‌تواند بیشتر از ۱۰۰۰۰ کاراکتر باشد.',
      );
    }

    return _postRepository.updatePost(
      postId: postId,
      userId: userId,
      content: normalizedContent,
    );
  }

  /// Soft-deletes a post owned by the authenticated user.
  Future<bool> deletePost({
    required int postId,
    required int userId,
  }) {
    if (postId < 1 || userId < 1) {
      throw const PostException('شناسه پست یا کاربر معتبر نیست.');
    }

    return _postRepository.deletePost(
      postId: postId,
      userId: userId,
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
