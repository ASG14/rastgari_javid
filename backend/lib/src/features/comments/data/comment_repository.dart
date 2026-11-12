import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles database operations for post comments and replies.
class CommentRepository {
  /// Returns comments for a post accessible to the viewer.
  Future<List<Map<String, dynamic>>?> getPostComments({
    required int postId,
    int? viewerUserId,
  }) async {
    final postResult = await database.execute(
      Sql.named('''
        SELECT p.id
        FROM public.posts AS p
        JOIN public.users AS u ON u.id = p.user_id
        WHERE p.id = @postId
          AND p.status = 'published'
          AND p.deleted_at IS NULL
          AND u.status = 'active'
          AND u.deleted_at IS NULL
          AND (
            p.user_id = CAST(@viewerUserId AS BIGINT)
            OR (
              p.visibility = 'public'
              AND (
                u.is_private = FALSE
                OR EXISTS (
                  SELECT 1
                  FROM public.user_follows AS uf
                  WHERE uf.follower_user_id =
                    CAST(@viewerUserId AS BIGINT)
                    AND uf.following_user_id = p.user_id
                )
              )
            )
            OR (
              p.visibility = 'followers'
              AND EXISTS (
                SELECT 1
                FROM public.user_follows AS uf
                WHERE uf.follower_user_id =
                  CAST(@viewerUserId AS BIGINT)
                  AND uf.following_user_id = p.user_id
              )
            )
          )
          AND (
            CAST(@viewerUserId AS BIGINT) IS NULL
            OR NOT EXISTS (
              SELECT 1
              FROM public.user_blocks AS ub
              WHERE (
                ub.blocker_user_id =
                  CAST(@viewerUserId AS BIGINT)
                AND ub.blocked_user_id = p.user_id
              )
              OR (
                ub.blocker_user_id = p.user_id
                AND ub.blocked_user_id =
                  CAST(@viewerUserId AS BIGINT)
              )
            )
          )
        LIMIT 1
      '''),
      parameters: {
        'postId': postId,
        'viewerUserId': viewerUserId,
      },
    );

    if (postResult.isEmpty) return null;

    final result = await database.execute(
      Sql.named('''
        WITH visible_top_level AS (
          SELECT c.id
          FROM public.comments AS c
          JOIN public.users AS u ON u.id = c.user_id
          WHERE c.post_id = @postId
            AND c.parent_comment_id IS NULL
            AND (
              c.deleted_at IS NULL
              OR EXISTS (
                SELECT 1
                FROM public.comments AS reply
                JOIN public.users AS reply_user
                  ON reply_user.id = reply.user_id
                WHERE reply.parent_comment_id = c.id
                  AND reply.deleted_at IS NULL
                  AND reply_user.status = 'active'
                  AND reply_user.deleted_at IS NULL
              )
            )
            AND u.status = 'active'
            AND u.deleted_at IS NULL
            AND (
              CAST(@viewerUserId AS BIGINT) IS NULL
              OR NOT EXISTS (
                SELECT 1
                FROM public.user_blocks AS ub
                WHERE (
                  ub.blocker_user_id =
                    CAST(@viewerUserId AS BIGINT)
                  AND ub.blocked_user_id = c.user_id
                )
                OR (
                  ub.blocker_user_id = c.user_id
                  AND ub.blocked_user_id =
                    CAST(@viewerUserId AS BIGINT)
                )
              )
            )
          ORDER BY c.created_at ASC, c.id ASC
          LIMIT 100
        )
        SELECT
          c.id,
          c.post_id,
          c.user_id,
          c.parent_comment_id,
          c.content,
          c.created_at,
          c.updated_at,
          c.deleted_at,
          u.username,
          u.display_name,
          u.avatar_storage_key
        FROM public.comments AS c
        JOIN public.users AS u ON u.id = c.user_id
        WHERE c.post_id = @postId
          AND (
            c.deleted_at IS NULL
            OR (
              c.parent_comment_id IS NULL
              AND EXISTS (
                SELECT 1
                FROM public.comments AS reply
                WHERE reply.parent_comment_id = c.id
                  AND reply.deleted_at IS NULL
              )
            )
          )
          AND u.status = 'active'
          AND u.deleted_at IS NULL
          AND (
            c.id IN (SELECT id FROM visible_top_level)
            OR c.parent_comment_id IN (
              SELECT id FROM visible_top_level
            )
          )
          AND (
            CAST(@viewerUserId AS BIGINT) IS NULL
            OR NOT EXISTS (
              SELECT 1
              FROM public.user_blocks AS ub
              WHERE (
                ub.blocker_user_id =
                  CAST(@viewerUserId AS BIGINT)
                AND ub.blocked_user_id = c.user_id
              )
              OR (
                ub.blocker_user_id = c.user_id
                AND ub.blocked_user_id =
                  CAST(@viewerUserId AS BIGINT)
              )
            )
          )
        ORDER BY
          COALESCE(c.parent_comment_id, c.id) ASC,
          (c.parent_comment_id IS NOT NULL) ASC,
          c.created_at ASC,
          c.id ASC
        LIMIT 600
      '''),
      parameters: {
        'postId': postId,
        'viewerUserId': viewerUserId,
      },
    );

    return result.map((row) {
      final data = row.toColumnMap();
      final isDeleted = data['deleted_at'] != null;

      final createdAt = data['created_at'];
      final updatedAt = data['updated_at'];

      final isEdited =
          !isDeleted &&
          createdAt is DateTime &&
          updatedAt is DateTime &&
          updatedAt.isAfter(createdAt);

      return {
        'id': data['id'],
        'post_id': data['post_id'],
        'parent_comment_id': data['parent_comment_id'],
        'content': isDeleted ? 'این دیدگاه حذف شده است.' : data['content'],
        'created_at': createdAt?.toString(),
        'updated_at': updatedAt?.toString(),
        'is_deleted': isDeleted,
        'is_edited': isEdited,
        'author': {
          'id': data['user_id'],
          'username': data['username'],
          'display_name': data['display_name'],
          'avatar_storage_key': data['avatar_storage_key'],
        },
      };
    }).toList();
  }

  /// Creates a comment or reply and updates the post comment counter.
  ///
  /// The user must be allowed to view the post, and comments must be enabled.
  Future<Map<String, dynamic>?> createComment({
    required int postId,
    required int userId,
    required String content,
    int? parentCommentId,
  }) {
    return database.runTx((session) async {
      final postResult = await session.execute(
        Sql.named('''
          SELECT
            p.id,
            p.user_id AS post_author_id
          FROM public.posts AS p
          JOIN public.users AS u ON u.id = p.user_id
          WHERE p.id = @postId
            AND p.status = 'published'
            AND p.deleted_at IS NULL
            AND p.comments_enabled = TRUE
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
                      AND uf.following_user_id = p.user_id
                  )
                )
              )
              OR (
                p.visibility = 'followers'
                AND EXISTS (
                  SELECT 1
                  FROM public.user_follows AS uf
                  WHERE uf.follower_user_id = @userId
                    AND uf.following_user_id = p.user_id
                )
              )
            )
            AND NOT EXISTS (
              SELECT 1
              FROM public.user_blocks AS ub
              WHERE (
                ub.blocker_user_id = @userId
                AND ub.blocked_user_id = p.user_id
              )
              OR (
                ub.blocker_user_id = p.user_id
                AND ub.blocked_user_id = @userId
              )
            )
          LIMIT 1
        '''),
        parameters: {
          'postId': postId,
          'userId': userId,
        },
      );

      if (postResult.isEmpty) return null;

      final postAuthorId =
          postResult.first.toColumnMap()['post_author_id'] as int;

      var notificationRecipientId = postAuthorId;

      final userResult = await session.execute(
        Sql.named('''
          SELECT id
          FROM public.users
          WHERE id = @userId
            AND status = 'active'
            AND deleted_at IS NULL
          LIMIT 1
        '''),
        parameters: {'userId': userId},
      );

      if (userResult.isEmpty) return null;

      if (parentCommentId != null) {
        final parentResult = await session.execute(
          Sql.named('''
            SELECT c.id, c.user_id AS parent_author_id
            FROM public.comments AS c
            JOIN public.users AS u ON u.id = c.user_id
            WHERE c.id = @parentCommentId
              AND c.post_id = @postId
              AND c.parent_comment_id IS NULL
              AND c.deleted_at IS NULL
              AND u.status = 'active'
              AND u.deleted_at IS NULL
              AND NOT EXISTS (
                SELECT 1
                FROM public.user_blocks AS ub
                WHERE (
                  ub.blocker_user_id = @userId
                  AND ub.blocked_user_id = c.user_id
                )
                OR (
                  ub.blocker_user_id = c.user_id
                  AND ub.blocked_user_id = @userId
                )
              )
            LIMIT 1
          '''),
          parameters: {
            'parentCommentId': parentCommentId,
            'postId': postId,
            'userId': userId,
          },
        );

        if (parentResult.isEmpty) return null;

        notificationRecipientId =
            parentResult.first.toColumnMap()['parent_author_id'] as int;
      }

      final inserted = await session.execute(
        Sql.named('''
          INSERT INTO public.comments (
            post_id,
            user_id,
            parent_comment_id,
            content
          )
          VALUES (
            @postId,
            @userId,
            @parentCommentId,
            @content
          )
          RETURNING
            id,
            post_id,
            user_id,
            parent_comment_id,
            content,
            created_at
        '''),
        parameters: {
          'postId': postId,
          'userId': userId,
          'parentCommentId': parentCommentId,
          'content': content,
        },
      );

      final row = inserted.first.toColumnMap();

      final authorResult = await session.execute(
        Sql.named('''
          SELECT username, display_name, avatar_storage_key
          FROM public.users
          WHERE id = @userId
        '''),
        parameters: {'userId': userId},
      );

      final author = authorResult.first.toColumnMap();

      await session.execute(
        Sql.named('''
          INSERT INTO public.post_stats (
            post_id,
            comments_count,
            updated_at
          )
          VALUES (@postId, 1, CURRENT_TIMESTAMP)
          ON CONFLICT (post_id) DO UPDATE
          SET comments_count = public.post_stats.comments_count + 1,
              updated_at = CURRENT_TIMESTAMP
        '''),
        parameters: {'postId': postId},
      );

      if (notificationRecipientId != userId) {
        await session.execute(
          Sql.named('''
            INSERT INTO public.notifications (
              recipient_user_id,
              actor_user_id,
              notification_type,
              post_id,
              comment_id
            )
            VALUES (
              @recipientUserId,
              @actorUserId,
              @notificationType,
              @postId,
              @commentId
            )
          '''),
          parameters: {
            'recipientUserId': notificationRecipientId,
            'actorUserId': userId,
            'notificationType': parentCommentId == null
                ? 'post_comment'
                : 'comment_reply',
            'postId': postId,
            'commentId': row['id'],
          },
        );
      }

      return {
        'id': row['id'],
        'post_id': row['post_id'],
        'parent_comment_id': row['parent_comment_id'],
        'content': row['content'],
        'created_at': row['created_at']?.toString(),
        'author': {
          'id': row['user_id'],
          'username': author['username'],
          'display_name': author['display_name'],
          'avatar_storage_key': author['avatar_storage_key'],
        },
      };
    });
  }

  /// Updates a comment owned by the specified user.
  ///
  /// Returns null if the comment is unavailable or not owned by the user.
  Future<Map<String, dynamic>?> updateComment({
    required int postId,
    required int commentId,
    required int userId,
    required String content,
  }) async {
    final result = await database.execute(
      Sql.named('''
        WITH updated_comment AS (
          UPDATE public.comments AS c
          SET
            content = @content,
            updated_at = CURRENT_TIMESTAMP
          WHERE c.id = @commentId
            AND c.post_id = @postId
            AND c.user_id = @userId
            AND c.deleted_at IS NULL
            AND EXISTS (
              SELECT 1
              FROM public.posts AS p
              WHERE p.id = c.post_id
                AND p.deleted_at IS NULL
            )
          RETURNING
            c.id,
            c.post_id,
            c.user_id,
            c.parent_comment_id,
            c.content,
            c.created_at,
            c.updated_at
        )
        SELECT
          c.id,
          c.post_id,
          c.user_id,
          c.parent_comment_id,
          c.content,
          c.created_at,
          c.updated_at,
          u.username,
          u.display_name,
          u.avatar_storage_key
        FROM updated_comment AS c
        JOIN public.users AS u ON u.id = c.user_id
        WHERE u.status = 'active'
          AND u.deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {
        'postId': postId,
        'commentId': commentId,
        'userId': userId,
        'content': content,
      },
    );

    if (result.isEmpty) return null;

    final row = result.first.toColumnMap();

    return {
      'id': row['id'],
      'post_id': row['post_id'],
      'parent_comment_id': row['parent_comment_id'],
      'content': row['content'],
      'created_at': row['created_at']?.toString(),
      'updated_at': row['updated_at']?.toString(),
      'is_edited': true,
      'is_deleted': false,
      'author': {
        'id': row['user_id'],
        'username': row['username'],
        'display_name': row['display_name'],
        'avatar_storage_key': row['avatar_storage_key'],
      },
    };
  }

  /// Soft-deletes a comment owned by the specified user.
  ///
  /// Returns false when the comment is unavailable or not owned by the user.
  Future<bool> deleteComment({
    required int postId,
    required int commentId,
    required int userId,
  }) async {
    return database.runTx((session) async {
      final result = await session.execute(
        Sql.named('''
          UPDATE public.comments AS c
          SET
            deleted_at = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
          WHERE c.id = @commentId
            AND c.post_id = @postId
            AND c.user_id = @userId
            AND c.deleted_at IS NULL
            AND EXISTS (
              SELECT 1
              FROM public.posts AS p
              WHERE p.id = c.post_id
                AND p.deleted_at IS NULL
            )
          RETURNING c.id, c.post_id
        '''),
        parameters: {
          'postId': postId,
          'commentId': commentId,
          'userId': userId,
        },
      );

      if (result.isEmpty) return false;

      final row = result.first.toColumnMap();

      await session.execute(
        Sql.named('''
          UPDATE public.post_stats
          SET
            comments_count = GREATEST(comments_count - 1, 0),
            updated_at = CURRENT_TIMESTAMP
          WHERE post_id = @postId
        '''),
        parameters: {'postId': row['post_id']},
      );

      return true;
    });
  }
}
