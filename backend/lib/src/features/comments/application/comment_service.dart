import 'package:backend/src/features/comments/data/comment_repository.dart';

/// Handles application rules for post comments and replies.
class CommentService {
  /// Creates a service with its repository dependency.
  CommentService(this._repository);

  final CommentRepository _repository;

  /// Returns comments for a post accessible to the optional viewer.
  Future<List<Map<String, dynamic>>?> getPostComments({
    required int postId,
    int? viewerUserId,
  }) {
    if (postId < 1) {
      throw const CommentException('شناسه پست معتبر نیست.');
    }

    if (viewerUserId != null && viewerUserId < 1) {
      throw const CommentException('شناسه کاربر معتبر نیست.');
    }

    return _repository.getPostComments(
      postId: postId,
      viewerUserId: viewerUserId,
    );
  }

  /// Publishes a comment or reply for an authenticated user.
  Future<Map<String, dynamic>?> createComment({
    required int postId,
    required int userId,
    required String content,
    int? parentCommentId,
  }) {
    if (postId < 1 || userId < 1) {
      throw const CommentException('شناسه پست یا کاربر معتبر نیست.');
    }

    if (parentCommentId != null && parentCommentId < 1) {
      throw const CommentException('شناسه دیدگاه والد معتبر نیست.');
    }

    final normalizedContent = content.trim();

    if (normalizedContent.isEmpty) {
      throw const CommentException('متن دیدگاه نمی‌تواند خالی باشد.');
    }

    if (normalizedContent.length > 5000) {
      throw const CommentException(
        'متن دیدگاه نمی‌تواند بیشتر از ۵۰۰۰ کاراکتر باشد.',
      );
    }

    return _repository.createComment(
      postId: postId,
      userId: userId,
      content: normalizedContent,
      parentCommentId: parentCommentId,
    );
  }

  /// Updates a comment owned by the authenticated user.
  Future<Map<String, dynamic>?> updateComment({
    required int postId,
    required int commentId,
    required int userId,
    required String content,
  }) {
    if (postId < 1 || commentId < 1 || userId < 1) {
      throw const CommentException(
        'شناسه پست، دیدگاه یا کاربر معتبر نیست.',
      );
    }

    final normalizedContent = content.trim();

    if (normalizedContent.isEmpty) {
      throw const CommentException(
        'متن دیدگاه نمی‌تواند خالی باشد.',
      );
    }

    if (normalizedContent.length > 5000) {
      throw const CommentException(
        'متن دیدگاه نمی‌تواند بیشتر از ۵۰۰۰ کاراکتر باشد.',
      );
    }

    return _repository.updateComment(
      postId: postId,
      commentId: commentId,
      userId: userId,
      content: normalizedContent,
    );
  }

  /// Soft-deletes a comment owned by the authenticated user.
  Future<bool> deleteComment({
    required int postId,
    required int commentId,
    required int userId,
  }) {
    if (postId < 1 || commentId < 1 || userId < 1) {
      throw const CommentException(
        'شناسه پست، دیدگاه یا کاربر معتبر نیست.',
      );
    }

    return _repository.deleteComment(
      postId: postId,
      commentId: commentId,
      userId: userId,
    );
  }
}

/// Represents a comment validation error.
class CommentException implements Exception {
  /// Creates a comment exception with a user-facing message.
  const CommentException(this.message);

  /// The validation message.
  final String message;

  @override
  String toString() => message;
}
