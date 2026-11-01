import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Provides database operations for posts.
class PostRepository {
  /// Retrieves the latest public posts and their author and statistics.
  Future<List<Map<String, dynamic>>> getPublicPosts() async {
    final result = await database.execute('''
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
        COALESCE(s.reposts_count, 0) AS reposts_count
      FROM posts AS p
      JOIN users AS u ON u.id = p.user_id
      LEFT JOIN post_stats AS s ON s.post_id = p.id
      WHERE
        p.status = 'published'
        AND p.visibility = 'public'
        AND p.deleted_at IS NULL
        AND u.deleted_at IS NULL
        AND u.status = 'active'
      ORDER BY p.published_at DESC NULLS LAST, p.id DESC
      LIMIT 50
    ''');

    return result.map((row) {
      return _mapPost(row.toColumnMap());
    }).toList();
  }

  /// Creates a public post and its initial statistics in one SQL statement.
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
          COALESCE(s.reposts_count, 0) AS reposts_count
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
    };
  }
}
