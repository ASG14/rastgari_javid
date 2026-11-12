import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles paginated queries for incoming and outgoing follow requests.
class FollowRequestQueryRepository {
  /// Returns pending follow requests for an authenticated user.
  ///
  /// When [incoming] is true, returns requests received by the user.
  /// Otherwise, returns requests created by the user.
  ///
  /// Inactive, deleted, and blocked accounts are excluded.
  Future<Map<String, dynamic>> getRequests({
    required int userId,
    required bool incoming,
    required int limit,
    required int offset,
  }) async {
    final ownerColumn = incoming ? 'target_user_id' : 'requester_user_id';
    final memberColumn = incoming ? 'requester_user_id' : 'target_user_id';

    const filters = '''
      r.status = 'pending'
      AND u.status = 'active'
      AND u.deleted_at IS NULL
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
    ''';

    final countResult = await database.execute(
      Sql.named('''
        SELECT COUNT(*) AS total
        FROM public.follow_requests AS r
        INNER JOIN public.users AS u
          ON u.id = r.$memberColumn
        WHERE r.$ownerColumn = @userId
          AND $filters
      '''),
      parameters: {'userId': userId},
    );

    final total = _toInt(
      countResult.first.toColumnMap()['total'],
    );

    final result = await database.execute(
      Sql.named('''
        SELECT
          r.id AS request_id,
          r.created_at,
          u.id AS user_id,
          u.username,
          u.display_name,
          u.bio,
          u.avatar_storage_key,

          EXISTS (
            SELECT 1
            FROM public.user_follows AS f
            WHERE f.follower_user_id = @userId
              AND f.following_user_id = u.id
          ) AS is_following,

          EXISTS (
            SELECT 1
            FROM public.user_follows AS f
            WHERE f.follower_user_id = u.id
              AND f.following_user_id = @userId
          ) AS is_followed_by

        FROM public.follow_requests AS r
        INNER JOIN public.users AS u
          ON u.id = r.$memberColumn
        WHERE r.$ownerColumn = @userId
          AND $filters
        ORDER BY r.created_at DESC, r.id DESC
        LIMIT @limit
        OFFSET @offset
      '''),
      parameters: {
        'userId': userId,
        'limit': limit,
        'offset': offset,
      },
    );

    final items = result.map((row) {
      final data = row.toColumnMap();

      return {
        'request_id': _toInt(data['request_id']),
        'created_at': data['created_at']?.toString(),
        'user': {
          'id': _toInt(data['user_id']),
          'username': data['username'],
          'display_name': data['display_name'],
          'bio': data['bio'],
          'avatar_storage_key': data['avatar_storage_key'],
        },
        'relationship': {
          'is_following': data['is_following'] == true,
          'is_followed_by': data['is_followed_by'] == true,
        },
      };
    }).toList();

    return {
      'items': items,
      'pagination': {
        'limit': limit,
        'offset': offset,
        'total': total,
        'has_more': offset + items.length < total,
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
