import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles database operations for user blocking.
class UserBlockRepository {
  /// Blocks a user and removes existing relationships in one transaction.
  Future<Map<String, dynamic>> blockUser({
    required int blockerUserId,
    required int blockedUserId,
  }) async {
    _validateIds(blockerUserId, blockedUserId);

    return database.runTx((session) async {
      final users = await session.execute(
        Sql.named('''
          SELECT id
          FROM public.users
          WHERE id IN (@blockerUserId, @blockedUserId)
            AND deleted_at IS NULL
            AND status = 'active'
          ORDER BY id ASC
          FOR UPDATE
        '''),
        parameters: {
          'blockerUserId': blockerUserId,
          'blockedUserId': blockedUserId,
        },
      );

      if (users.length != 2) {
        return {'status': 'user_not_found'};
      }

      final existingBlock = await session.execute(
        Sql.named('''
          SELECT EXISTS (
            SELECT 1
            FROM public.user_blocks
            WHERE blocker_user_id = @blockerUserId
              AND blocked_user_id = @blockedUserId
          )
        '''),
        parameters: {
          'blockerUserId': blockerUserId,
          'blockedUserId': blockedUserId,
        },
      );

      if (existingBlock.first[0] == true) {
        return {'status': 'already_blocked'};
      }

      await session.execute(
        Sql.named('''
          INSERT INTO public.user_blocks (
            blocker_user_id,
            blocked_user_id
          )
          VALUES (
            @blockerUserId,
            @blockedUserId
          )
          ON CONFLICT (
            blocker_user_id,
            blocked_user_id
          ) DO NOTHING
        '''),
        parameters: {
          'blockerUserId': blockerUserId,
          'blockedUserId': blockedUserId,
        },
      );

      // Remove follows in both directions.
      await session.execute(
        Sql.named('''
          DELETE FROM public.user_follows
          WHERE (
            follower_user_id = @blockerUserId
            AND following_user_id = @blockedUserId
          )
          OR (
            follower_user_id = @blockedUserId
            AND following_user_id = @blockerUserId
          )
        '''),
        parameters: {
          'blockerUserId': blockerUserId,
          'blockedUserId': blockedUserId,
        },
      );

      // Cancel pending requests in either direction.
      await session.execute(
        Sql.named('''
          UPDATE public.follow_requests
          SET
            status = 'cancelled',
            updated_at = CURRENT_TIMESTAMP,
            responded_at = CURRENT_TIMESTAMP
          WHERE status = 'pending'
            AND (
              (
                requester_user_id = @blockerUserId
                AND target_user_id = @blockedUserId
              )
              OR (
                requester_user_id = @blockedUserId
                AND target_user_id = @blockerUserId
              )
            )
        '''),
        parameters: {
          'blockerUserId': blockerUserId,
          'blockedUserId': blockedUserId,
        },
      );

      return {'status': 'blocked'};
    });
  }

  /// Removes a block without restoring previous relationships.
  Future<Map<String, dynamic>> unblockUser({
    required int blockerUserId,
    required int blockedUserId,
  }) async {
    _validateIds(blockerUserId, blockedUserId);

    return database.runTx((session) async {
      final users = await session.execute(
        Sql.named('''
          SELECT id
          FROM public.users
          WHERE id IN (@blockerUserId, @blockedUserId)
            AND deleted_at IS NULL
            AND status = 'active'
          ORDER BY id ASC
          FOR UPDATE
        '''),
        parameters: {
          'blockerUserId': blockerUserId,
          'blockedUserId': blockedUserId,
        },
      );

      if (users.length != 2) {
        return {'status': 'user_not_found'};
      }

      final result = await session.execute(
        Sql.named('''
          DELETE FROM public.user_blocks
          WHERE blocker_user_id = @blockerUserId
            AND blocked_user_id = @blockedUserId
          RETURNING blocker_user_id
        '''),
        parameters: {
          'blockerUserId': blockerUserId,
          'blockedUserId': blockedUserId,
        },
      );

      if (result.isEmpty) {
        return {'status': 'not_blocked'};
      }

      return {'status': 'unblocked'};
    });
  }

  void _validateIds(int firstId, int secondId) {
    if (firstId < 1 || secondId < 1) {
      throw ArgumentError('User IDs must be positive.');
    }

    if (firstId == secondId) {
      throw ArgumentError('A user cannot block themselves.');
    }
  }
}
