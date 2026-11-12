import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Provides database operations for posts and post interactions.
class PostRepository {
  /// Retrieves posts visible to the current user.
  ///
  /// Retrieves a single post if it is visible to the current user.
  ///
  /// Returns null when the post does not exist or access is denied.
  Future<Map<String, dynamic>?> getPostById({
    required int postId,
    int? currentUserId,
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
          CASE
            WHEN CAST(@currentUserId AS BIGINT) IS NULL THEN FALSE
            ELSE EXISTS (
              SELECT 1
              FROM public.post_likes AS pl
              WHERE pl.post_id = p.id
                AND pl.user_id = CAST(@currentUserId AS BIGINT)
            )
          END AS is_liked
        FROM public.posts AS p
        JOIN public.users AS u ON u.id = p.user_id
        LEFT JOIN public.post_stats AS s ON s.post_id = p.id
        WHERE p.id = @postId
          AND p.status = 'published'
          AND p.deleted_at IS NULL
          AND u.status = 'active'
          AND u.deleted_at IS NULL

          AND (
            p.user_id = CAST(@currentUserId AS BIGINT)

            OR (
              p.visibility = 'public'
              AND (
                u.is_private = FALSE
                OR EXISTS (
                  SELECT 1
                  FROM public.user_follows AS uf
                  WHERE uf.follower_user_id =
                    CAST(@currentUserId AS BIGINT)
                    AND uf.following_user_id = u.id
                )
              )
            )

            OR (
              p.visibility = 'followers'
              AND EXISTS (
                SELECT 1
                FROM public.user_follows AS uf
                WHERE uf.follower_user_id =
                  CAST(@currentUserId AS BIGINT)
                  AND uf.following_user_id = u.id
              )
            )
          )

          AND (
            CAST(@currentUserId AS BIGINT) IS NULL
            OR NOT EXISTS (
              SELECT 1
              FROM public.user_blocks AS b
              WHERE (
                b.blocker_user_id = CAST(@currentUserId AS BIGINT)
                AND b.blocked_user_id = u.id
              )
              OR (
                b.blocker_user_id = u.id
                AND b.blocked_user_id = CAST(@currentUserId AS BIGINT)
              )
            )
          )
        LIMIT 1
      '''),
      parameters: {
        'postId': postId,
        'currentUserId': currentUserId,
      },
    );

    if (result.isEmpty) return null;

    return _mapPost(result.first.toColumnMap());
  }

  /// Public posts from public accounts are visible to everyone.
  /// Posts from private accounts are visible only to accepted followers.
  /// Followers-only posts are visible to followers and their author.
  /// Private posts are visible only to their author.
  Future<List<Map<String, dynamic>>> getPublicPosts({
    int? currentUserId,
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
          CASE
            WHEN CAST(@currentUserId AS BIGINT) IS NULL THEN FALSE
            ELSE EXISTS (
              SELECT 1
              FROM public.post_likes AS pl
              WHERE pl.post_id = p.id
                AND pl.user_id = CAST(@currentUserId AS BIGINT)
            )
          END AS is_liked
        FROM public.posts AS p
        JOIN public.users AS u ON u.id = p.user_id
        LEFT JOIN public.post_stats AS s ON s.post_id = p.id
        WHERE
          p.status = 'published'
          AND p.deleted_at IS NULL
          AND u.deleted_at IS NULL
          AND u.status = 'active'

          AND (
            p.user_id = CAST(@currentUserId AS BIGINT)

            OR (
              p.visibility = 'public'
              AND (
                u.is_private = FALSE
                OR EXISTS (
                  SELECT 1
                  FROM public.user_follows AS uf
                  WHERE uf.follower_user_id =
                    CAST(@currentUserId AS BIGINT)
                    AND uf.following_user_id = u.id
                )
              )
            )

            OR (
              p.visibility = 'followers'
              AND EXISTS (
                SELECT 1
                FROM public.user_follows AS uf
                WHERE uf.follower_user_id =
                  CAST(@currentUserId AS BIGINT)
                  AND uf.following_user_id = u.id
              )
            )
          )

          AND (
            CAST(@currentUserId AS BIGINT) IS NULL
            OR NOT EXISTS (
              SELECT 1
              FROM public.user_blocks AS b
              WHERE (
                b.blocker_user_id = CAST(@currentUserId AS BIGINT)
                AND b.blocked_user_id = u.id
              )
              OR (
                b.blocker_user_id = u.id
                AND b.blocked_user_id = CAST(@currentUserId AS BIGINT)
              )
            )
          )

        ORDER BY p.published_at DESC NULLS LAST, p.id DESC
        LIMIT 50
      '''),
      parameters: {'currentUserId': currentUserId},
    );

    return result.map((row) {
      return _mapPost(row.toColumnMap());
    }).toList();
  }

  /// Creates a public post and its initial statistics in one SQL statement.
  ///
  /// Account privacy is enforced when posts are retrieved, not by changing
  /// the post's visibility value.
  Future<Map<String, dynamic>> createPublicPost({
    required int userId,
    required String content,
  }) async {
    final result = await database.execute(
      Sql.named('''
        WITH new_post AS (
          INSERT INTO public.posts (
            user_id,
            content,
            visibility,
            status,
            published_at
          )
          VALUES (
            @userId,
            @content,
            'public',
            'published',
            CURRENT_TIMESTAMP
          )
          RETURNING
            id,
            user_id,
            content,
            visibility,
            published_at,
            created_at
        ),
        new_stats AS (
          INSERT INTO public.post_stats (post_id)
          SELECT id
          FROM new_post
          RETURNING post_id
        )
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
          FALSE AS is_liked
        FROM new_post AS p
        JOIN new_stats AS ns ON ns.post_id = p.id
        JOIN public.users AS u ON u.id = p.user_id
        LEFT JOIN public.post_stats AS s ON s.post_id = p.id
      '''),
      parameters: {
        'userId': userId,
        'content': content,
      },
    );

    if (result.isEmpty) {
      throw StateError('The post was not created.');
    }

    return _mapPost(result.first.toColumnMap());
  }

  /// Updates a published post owned by the specified user.
  ///
  /// Returns null when the post does not exist or is not owned by the user.
  Future<Map<String, dynamic>?> updatePost({
    required int postId,
    required int userId,
    required String content,
  }) async {
    final result = await database.execute(
      Sql.named('''
        WITH updated_post AS (
          UPDATE public.posts
          SET
            content = @content,
            updated_at = CURRENT_TIMESTAMP
          WHERE id = @postId
            AND user_id = @userId
            AND status = 'published'
            AND deleted_at IS NULL
          RETURNING
            id,
            user_id,
            content,
            visibility,
            published_at,
            created_at
        )
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
              AND pl.user_id = @userId
          ) AS is_liked
        FROM updated_post AS p
        JOIN public.users AS u ON u.id = p.user_id
        LEFT JOIN public.post_stats AS s ON s.post_id = p.id
        LIMIT 1
      '''),
      parameters: {
        'postId': postId,
        'userId': userId,
        'content': content,
      },
    );

    if (result.isEmpty) return null;

    return _mapPost(result.first.toColumnMap());
  }

  /// Soft-deletes a post owned by the specified user.
  ///
  /// Returns false when the post does not exist or is not owned by the user.
  Future<bool> deletePost({
    required int postId,
    required int userId,
  }) async {
    final result = await database.execute(
      Sql.named('''
        UPDATE public.posts
        SET
          deleted_at = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP
        WHERE id = @postId
          AND user_id = @userId
          AND deleted_at IS NULL
        RETURNING id
      '''),
      parameters: {
        'postId': postId,
        'userId': userId,
      },
    );

    return result.isNotEmpty;
  }

  /// Adds or removes a user's like and returns the resulting state.
  ///
  /// Returns null when the post is not available to the current user.
  Future<Map<String, dynamic>?> setPostLike({
    required int postId,
    required int userId,
    required bool isLiked,
  }) {
    return database.runTx((session) async {
      final postResult = await session.execute(
        Sql.named('''
          SELECT
            p.id,
            p.user_id AS author_id
          FROM public.posts AS p
          JOIN public.users AS u ON u.id = p.user_id
          WHERE p.id = @postId
            AND p.status = 'published'
            AND p.deleted_at IS NULL
            AND u.status = 'active'
            AND u.deleted_at IS NULL

            AND (
              p.user_id = @userId

              OR (
                p.visibility = 'public'
                AND (
                  u.is_private = FALSE
                  OR EXISTS (
                    SELECT 1
                    FROM public.user_follows AS uf
                    WHERE uf.follower_user_id = @userId
                      AND uf.following_user_id = u.id
                  )
                )
              )

              OR (
                p.visibility = 'followers'
                AND EXISTS (
                  SELECT 1
                  FROM public.user_follows AS uf
                  WHERE uf.follower_user_id = @userId
                    AND uf.following_user_id = u.id
                )
              )
            )

            AND NOT EXISTS (
              SELECT 1
              FROM public.user_blocks AS b
              WHERE (
                b.blocker_user_id = @userId
                AND b.blocked_user_id = u.id
              )
              OR (
                b.blocker_user_id = u.id
                AND b.blocked_user_id = @userId
              )
            )

          LIMIT 1
        '''),
        parameters: {
          'postId': postId,
          'userId': userId,
        },
      );

      if (postResult.isEmpty) {
        return null;
      }

      if (isLiked) {
        final insertResult = await session.execute(
          Sql.named('''
            INSERT INTO public.post_likes (post_id, user_id)
            VALUES (@postId, @userId)
            ON CONFLICT (post_id, user_id) DO NOTHING
            RETURNING post_id
          '''),
          parameters: {
            'postId': postId,
            'userId': userId,
          },
        );

        if (insertResult.isNotEmpty) {
          await session.execute(
            Sql.named('''
              INSERT INTO public.post_stats (
                post_id,
                likes_count,
                updated_at
              )
              VALUES (@postId, 1, CURRENT_TIMESTAMP)
              ON CONFLICT (post_id) DO UPDATE
              SET likes_count = public.post_stats.likes_count + 1,
                  updated_at = CURRENT_TIMESTAMP
            '''),
            parameters: {'postId': postId},
          );

          final postAuthorId =
              postResult.first.toColumnMap()['author_id'] as int;

          if (postAuthorId != userId) {
            await session.execute(
              Sql.named('''
                INSERT INTO public.notifications (
                  recipient_user_id,
                  actor_user_id,
                  notification_type,
                  post_id
                )
                VALUES (
                  @recipientUserId,
                  @actorUserId,
                  'post_like',
                  @postId
                )
              '''),
              parameters: {
                'recipientUserId': postAuthorId,
                'actorUserId': userId,
                'postId': postId,
              },
            );
          }
        }
      } else {
        final deleteResult = await session.execute(
          Sql.named('''
            DELETE FROM public.post_likes
            WHERE post_id = @postId
              AND user_id = @userId
            RETURNING post_id
          '''),
          parameters: {
            'postId': postId,
            'userId': userId,
          },
        );

        if (deleteResult.isNotEmpty) {
          await session.execute(
            Sql.named('''
              INSERT INTO public.post_stats (
                post_id,
                likes_count,
                updated_at
              )
              VALUES (@postId, 0, CURRENT_TIMESTAMP)
              ON CONFLICT (post_id) DO UPDATE
              SET likes_count = GREATEST(
                    public.post_stats.likes_count - 1,
                    0
                  ),
                  updated_at = CURRENT_TIMESTAMP
            '''),
            parameters: {'postId': postId},
          );
        }
      }

      final stateResult = await session.execute(
        Sql.named('''
          SELECT
            EXISTS (
              SELECT 1
              FROM public.post_likes
              WHERE post_id = @postId
                AND user_id = @userId
            ) AS is_liked,
            COALESCE(
              (
                SELECT likes_count
                FROM public.post_stats
                WHERE post_id = @postId
              ),
              0
            ) AS likes_count
        '''),
        parameters: {
          'postId': postId,
          'userId': userId,
        },
      );

      final state = stateResult.first.toColumnMap();

      return {
        'post_id': postId,
        'is_liked': state['is_liked'] == true,
        'likes_count': state['likes_count'],
      };
    });
  }

  Map<String, dynamic> _mapPost(Map<String, dynamic> data) {
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
  }
}
