
import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Provides database access to posts displayed on a user's profile.
class UserProfilePostRepository {
  /// Retrieves a page of posts visible to the viewer on a target profile.
  ///
  /// The author can see all of their own published posts.
  /// Other viewers can only see posts permitted by account privacy
  /// and post visibility settings.
  Future<List<Map<String, dynamic>>> getUserPosts({
    required int targetUserId,
    required int currentUserId,
    required int limit,
    int? cursorPostId,
    DateTime? cursorPublishedAt,
    required bool cursorPublishedAtIsNull,
  }) async {
    final result = await database.execute(
      Sql.named('''
        SELECT
          p.id AS post_id,
          p.content,
          p.visibility,
          p.published_at,
          p.created_at,
          u.id AS author_id,
          u.username,
          u.display_name,
          u.avatar_storage_key,
          COALESCE(s.likes_count, 0) AS likes_count,
          COALESCE(s.comments_count, 0) AS comments_count,
          COALESCE(s.reposts_count, 0) AS reposts_count,
          EXISTS (
            SELECT 1
            FROM public.post_likes AS pl
            WHERE pl.post_id = p.id
              AND pl.user_id = @currentUserId
          ) AS is_liked
        FROM public.posts AS p
        JOIN public.users AS u ON u.id = p.user_id
        LEFT JOIN public.post_stats AS s ON s.post_id = p.id
        WHERE
          p.user_id = @targetUserId
          AND p.status = 'published'
          AND p.deleted_at IS NULL
          AND u.status = 'active'
          AND u.deleted_at IS NULL

          AND (
            p.user_id = @currentUserId

            OR (
              p.visibility = 'public'
              AND (
                u.is_private = FALSE
                OR EXISTS (
                  SELECT 1
                  FROM public.user_follows AS uf
                  WHERE uf.follower_user_id = @currentUserId
                    AND uf.following_user_id = u.id
                )
              )
            )

            OR (
              p.visibility = 'followers'
              AND EXISTS (
                SELECT 1
                FROM public.user_follows AS uf
                WHERE uf.follower_user_id = @currentUserId
                  AND uf.following_user_id = u.id
              )
            )
          )

          AND NOT EXISTS (
            SELECT 1
            FROM public.user_blocks AS b
            WHERE (
              b.blocker_user_id = @currentUserId
              AND b.blocked_user_id = u.id
            )
            OR (
              b.blocker_user_id = u.id
              AND b.blocked_user_id = @currentUserId
            )
          )

          AND (
            CAST(@cursorPostId AS BIGINT) IS NULL

            OR (
              @cursorPublishedAtIsNull = FALSE
              AND (
                p.published_at IS NULL
                OR p.published_at < @cursorPublishedAt
                OR (
                  p.published_at = @cursorPublishedAt
                  AND p.id < CAST(@cursorPostId AS BIGINT)
                )
              )
            )

            OR (
              @cursorPublishedAtIsNull = TRUE
              AND p.published_at IS NULL
              AND p.id < CAST(@cursorPostId AS BIGINT)
            )
          )

        ORDER BY p.published_at DESC NULLS LAST, p.id DESC
        LIMIT @fetchLimit
      '''),
      parameters: {
        'targetUserId': targetUserId,
        'currentUserId': currentUserId,
        'cursorPostId': cursorPostId,
        'cursorPublishedAt': cursorPublishedAt,
        'cursorPublishedAtIsNull': cursorPublishedAtIsNull,
        'fetchLimit': limit + 1,
      },
    );

    return result.map((row) {
      final data = row.toColumnMap();

      return {
        'id': data['post_id'],
        'content': data['content'],
        'visibility': data['visibility'],
        'published_at': data['published_at']?.toString(),
        'created_at': data['created_at']?.toString(),
        'author': {
          'id': data['author_id'],
          'username': data['username'],
          'display_name': data['display_name'],
          'avatar_storage_key': data['avatar_storage_key'],
        },
        'likes_count': data['likes_count'],
        'comments_count': data['comments_count'],
        'reposts_count': data['reposts_count'],
        'is_liked': data['is_liked'] == true,
      };
    }).toList();
  }
}
