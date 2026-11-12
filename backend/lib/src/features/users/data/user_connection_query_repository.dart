import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles paginated follower and following queries.
class UserConnectionQueryRepository {
  /// Returns a user's followers or following accounts.
  ///
  /// Inactive, deleted, and blocked accounts are excluded.
  Future<Map<String, dynamic>> getConnections({
    required int viewerUserId,
    required int targetUserId,
    required bool followers,
    required int limit,
    required int offset,
  }) async {
    final targetResult = await database.execute(
      Sql.named('''
        SELECT
          u.id,
          u.is_private,

          EXISTS (
            SELECT 1
            FROM public.user_follows
            WHERE follower_user_id = @viewerUserId
              AND following_user_id = u.id
          ) AS is_following,

          EXISTS (
            SELECT 1
            FROM public.user_blocks
            WHERE (
              blocker_user_id = @viewerUserId
              AND blocked_user_id = u.id
            )
            OR (
              blocker_user_id = u.id
              AND blocked_user_id = @viewerUserId
            )
          ) AS is_blocked

        FROM public.users AS u
        WHERE u.id = @targetUserId
          AND u.status = 'active'
          AND u.deleted_at IS NULL
        LIMIT 1
      '''),
      parameters: {
        'viewerUserId': viewerUserId,
        'targetUserId': targetUserId,
      },
    );

    if (targetResult.isEmpty) {
      return {'status': 'not_found'};
    }

    final target = targetResult.first.toColumnMap();

    if (target['is_blocked'] == true) {
      return {'status': 'not_found'};
    }

    final isOwnProfile = viewerUserId == targetUserId;
    final isPrivate = target['is_private'] == true;
    final isFollowing = target['is_following'] == true;

    if (isPrivate && !isOwnProfile && !isFollowing) {
      return {'status': 'private'};
    }

    final relationColumn = followers ? 'following_user_id' : 'follower_user_id';

    final memberColumn = followers ? 'follower_user_id' : 'following_user_id';

    final countResult = await database.execute(
      Sql.named('''
        SELECT COUNT(*) AS total
        FROM public.user_follows AS f
        INNER JOIN public.users AS u
          ON u.id = f.$memberColumn
        WHERE f.$relationColumn = @targetUserId
          AND u.status = 'active'
          AND u.deleted_at IS NULL
          AND NOT EXISTS (
            SELECT 1
            FROM public.user_blocks AS b
            WHERE (
              b.blocker_user_id = @viewerUserId
              AND b.blocked_user_id = u.id
            )
            OR (
              b.blocker_user_id = u.id
              AND b.blocked_user_id = @viewerUserId
            )
          )
      '''),
      parameters: {
        'viewerUserId': viewerUserId,
        'targetUserId': targetUserId,
      },
    );

    final total = _toInt(
      countResult.first.toColumnMap()['total'],
    );

    final result = await database.execute(
      Sql.named('''
        SELECT
          u.id,
          u.username,
          u.display_name,
          u.bio,
          u.avatar_storage_key,
          f.created_at AS connection_created_at,

          EXISTS (
            SELECT 1
            FROM public.user_follows AS vf
            WHERE vf.follower_user_id = @viewerUserId
              AND vf.following_user_id = u.id
          ) AS is_following,

          EXISTS (
            SELECT 1
            FROM public.user_follows AS uf
            WHERE uf.follower_user_id = u.id
              AND uf.following_user_id = @viewerUserId
          ) AS is_followed_by

        FROM public.user_follows AS f
        INNER JOIN public.users AS u
          ON u.id = f.$memberColumn
        WHERE f.$relationColumn = @targetUserId
          AND u.status = 'active'
          AND u.deleted_at IS NULL
          AND NOT EXISTS (
            SELECT 1
            FROM public.user_blocks AS b
            WHERE (
              b.blocker_user_id = @viewerUserId
              AND b.blocked_user_id = u.id
            )
            OR (
              b.blocker_user_id = u.id
              AND b.blocked_user_id = @viewerUserId
            )
          )
        ORDER BY f.created_at DESC, u.id DESC
        LIMIT @limit
        OFFSET @offset
      '''),
      parameters: {
        'viewerUserId': viewerUserId,
        'targetUserId': targetUserId,
        'limit': limit,
        'offset': offset,
      },
    );

    final items = result.map((row) {
      final data = row.toColumnMap();

      return {
        'id': _toInt(data['id']),
        'username': data['username'],
        'display_name': data['display_name'],
        'bio': data['bio'],
        'avatar_storage_key': data['avatar_storage_key'],
        'connection_created_at': data['connection_created_at']?.toString(),
        'relationship': {
          'is_following': data['is_following'] == true,
          'is_followed_by': data['is_followed_by'] == true,
        },
      };
    }).toList();

    return {
      'status': 'found',
      'data': {
        'items': items,
        'pagination': {
          'limit': limit,
          'offset': offset,
          'total': total,
          'has_more': offset + items.length < total,
        },
      },
    };
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is num) return value.toInt();

    return int.parse(value.toString());
  }
}
