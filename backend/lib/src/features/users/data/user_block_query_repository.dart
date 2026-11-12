
import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles read operations for blocked users.
class UserBlockQueryRepository {
  /// Returns a paginated list of users blocked by [userId].
  Future<Map<String, dynamic>> getBlockedUsers({
    required int userId,
    required int limit,
    required int offset,
  }) async {
    final countResult = await database.execute(
      Sql.named('''
        SELECT COUNT(*)
        FROM public.user_blocks ub
        INNER JOIN public.users u
          ON u.id = ub.blocked_user_id
        WHERE ub.blocker_user_id = @userId
          AND u.deleted_at IS NULL
          AND u.status = 'active'
      '''),
      parameters: {'userId': userId},
    );

    final total = countResult.first[0] as int;

    final result = await database.execute(
      Sql.named('''
        SELECT
          u.id,
          u.username,
          u.display_name,
          u.bio,
          u.avatar_storage_key,
          ub.created_at AS blocked_at
        FROM public.user_blocks ub
        INNER JOIN public.users u
          ON u.id = ub.blocked_user_id
        WHERE ub.blocker_user_id = @userId
          AND u.deleted_at IS NULL
          AND u.status = 'active'
        ORDER BY ub.created_at DESC, u.id DESC
        LIMIT @limit
        OFFSET @offset
      '''),
      parameters: {
        'userId': userId,
        'limit': limit,
        'offset': offset,
      },
    );

    final items = result.map((row) => row.toColumnMap()).toList();

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
}
