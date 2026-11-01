import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles database operations for post comments.
class CommentRepository {
  /// Returns visible top-level comments for a public post.
  Future<List<Map<String, dynamic>>?> getPostComments({
    required int postId,
  }) async {
    final result = await database.execute(
      Sql.named('''
        SELECT p.id
        FROM public.posts AS p
        JOIN public.users AS u ON u.id = p.user_id
        WHERE p.id = @postId
          AND p.status = 'published'
          AND p.visibility = 'public'
          AND p.deleted_at IS NULL
          AND u.status = 'active'
          AND u.deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {'postId': postId},
    );

    if (result.isEmpty) return null;

    final comments = await database.execute(
      Sql.named('''
        SELECT
          c.id,
          c.post_id,
          c.user_id,
          c.content,
          c.created_at,
          u.username,
          u.display_name,
          u.avatar_storage_key
        FROM public.comments AS c
        JOIN public.users AS u ON u.id = c.user_id
        WHERE c.post_id = @postId
          AND c.parent_comment_id IS NULL
          AND c.deleted_at IS NULL
          AND u.status = 'active'
          AND u.deleted_at IS NULL
        ORDER BY c.created_at ASC, c.id ASC
        LIMIT 100
      '''),
      parameters: {'postId': postId},
    );

    return comments.map((row) {
      final data = row.toColumnMap();

      return {
        'id': data['id'],
        'post_id': data['post_id'],
        'content': data['content'],
        'created_at': data['created_at']?.toString(),
        'author': {
          'id': data['user_id'],
          'username': data['username'],
          'display_name': data['display_name'],
          'avatar_storage_key': data['avatar_storage_key'],
        },
      };
    }).toList();
  }

  /// Creates a comment and increments the post's comment counter atomically.
  Future<Map<String, dynamic>?> createComment({
    required int postId,
    required int userId,
    required String content,
  }) {
    return database.runTx((session) async {
      final postResult = await session.execute(
        Sql.named('''
          SELECT p.id
          FROM public.posts AS p
          JOIN public.users AS u ON u.id = p.user_id
          WHERE p.id = @postId
            AND p.status = 'published'
            AND p.visibility = 'public'
            AND p.deleted_at IS NULL
            AND u.status = 'active'
            AND u.deleted_at IS NULL
          LIMIT 1
        '''),
        parameters: {'postId': postId},
      );

      if (postResult.isEmpty) return null;

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

      final inserted = await session.execute(
        Sql.named('''
          INSERT INTO public.comments (
            post_id,
            user_id,
            content
          )
          VALUES (
            @postId,
            @userId,
            @content
          )
          RETURNING id, post_id, user_id, content, created_at
        '''),
        parameters: {
          'postId': postId,
          'userId': userId,
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

      return {
        'id': row['id'],
        'post_id': row['post_id'],
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
}
