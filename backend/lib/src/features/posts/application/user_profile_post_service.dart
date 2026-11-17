
import 'dart:convert';

import 'package:backend/src/features/posts/data/user_profile_post_repository.dart';

/// Handles paginated post retrieval for public user profiles.
class UserProfilePostService {
  /// Creates the service with its repository dependency.
  UserProfilePostService(this._repository);

  final UserProfilePostRepository _repository;

  /// Returns a page of posts visible to the current viewer.
  Future<Map<String, dynamic>> getUserPosts({
    required int targetUserId,
    required int currentUserId,
    int limit = 20,
    String? cursor,
  }) async {
    if (targetUserId < 1 || currentUserId < 1) {
      throw const UserProfilePostException(
        'شناسه کاربر معتبر نیست.',
      );
    }

    if (limit < 1 || limit > 50) {
      throw const UserProfilePostException(
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
        throw const UserProfilePostException(
          'نشانگر صفحه‌بندی معتبر نیست.',
        );
      }
    }

    final rows = await _repository.getUserPosts(
      targetUserId: targetUserId,
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

      nextCursor = base64Url.encode(
        utf8.encode(cursorData),
      );
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
}

/// Represents a validation error in user profile post retrieval.
class UserProfilePostException implements Exception {
  /// Creates an exception with a user-facing message.
  const UserProfilePostException(this.message);

  /// The validation message.
  final String message;

  @override
  String toString() => message;
}
