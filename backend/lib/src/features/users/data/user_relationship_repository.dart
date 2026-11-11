import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles database operations for user-to-user relationships.
class UserRelationshipRepository {
  /// Creates a follow relationship or a follow request.
  ///
  /// Public accounts are followed immediately.
  /// Private accounts receive a pending follow request.
  ///
  /// The relationship and its notification are created in one transaction.
  Future<Map<String, dynamic>> followUser({
    required int actorUserId,
    required int targetUserId,
  }) {
    if (actorUserId < 1 || targetUserId < 1) {
      throw ArgumentError('User IDs must be positive.');
    }

    if (actorUserId == targetUserId) {
      throw ArgumentError('A user cannot follow themselves.');
    }

    return database.runTx((session) async {
      // Verify that the requesting account is active.
      final actorResult = await session.execute(
        Sql.named('''
          SELECT id
          FROM public.users
          WHERE id = @actorUserId
            AND deleted_at IS NULL
            AND status = 'active'
          LIMIT 1
        '''),
        parameters: {
          'actorUserId': actorUserId,
        },
      );

      if (actorResult.isEmpty) {
        return {
          'status': 'actor_not_found',
        };
      }

      // Lock the target account to prevent privacy changes from racing
      // with the creation of a follow or follow request.
      final targetResult = await session.execute(
        Sql.named('''
          SELECT id, is_private
          FROM public.users
          WHERE id = @targetUserId
            AND deleted_at IS NULL
            AND status = 'active'
          LIMIT 1
          FOR UPDATE
        '''),
        parameters: {
          'targetUserId': targetUserId,
        },
      );

      if (targetResult.isEmpty) {
        return {
          'status': 'target_not_found',
        };
      }

      final target = targetResult.first.toColumnMap();
      final isPrivate = target['is_private'] as bool;

      // A block in either direction prevents following.
      final blockResult = await session.execute(
        Sql.named('''
          SELECT EXISTS (
            SELECT 1
            FROM public.user_blocks
            WHERE (
              blocker_user_id = @actorUserId
              AND blocked_user_id = @targetUserId
            )
            OR (
              blocker_user_id = @targetUserId
              AND blocked_user_id = @actorUserId
            )
          )
        '''),
        parameters: {
          'actorUserId': actorUserId,
          'targetUserId': targetUserId,
        },
      );

      if (blockResult.first[0] == true) {
        return {
          'status': 'blocked',
        };
      }

      // Check whether the relationship already exists.
      final followResult = await session.execute(
        Sql.named('''
          SELECT EXISTS (
            SELECT 1
            FROM public.user_follows
            WHERE follower_user_id = @actorUserId
              AND following_user_id = @targetUserId
          )
        '''),
        parameters: {
          'actorUserId': actorUserId,
          'targetUserId': targetUserId,
        },
      );

      if (followResult.first[0] == true) {
        return {
          'status': 'already_following',
        };
      }

      if (isPrivate) {
        // Only one pending request is allowed for each unordered pair.
        final pendingResult = await session.execute(
          Sql.named('''
            SELECT
              id,
              requester_user_id,
              target_user_id
            FROM public.follow_requests
            WHERE status = 'pending'
              AND LEAST(requester_user_id, target_user_id) =
                  LEAST(@actorUserId, @targetUserId)
              AND GREATEST(requester_user_id, target_user_id) =
                  GREATEST(@actorUserId, @targetUserId)
            LIMIT 1
          '''),
          parameters: {
            'actorUserId': actorUserId,
            'targetUserId': targetUserId,
          },
        );

        if (pendingResult.isNotEmpty) {
          final pending = pendingResult.first.toColumnMap();

          final requesterId = _toInt(pending['requester_user_id']);

          return {
            'status': requesterId == actorUserId
                ? 'request_already_pending'
                : 'incoming_request_pending',
            'follow_request_id': pending['id'],
          };
        }

        // Create a new request for the private account.
        final requestResult = await session.execute(
          Sql.named('''
            INSERT INTO public.follow_requests (
              requester_user_id,
              target_user_id,
              status
            )
            VALUES (
              @actorUserId,
              @targetUserId,
              'pending'
            )
            RETURNING id
          '''),
          parameters: {
            'actorUserId': actorUserId,
            'targetUserId': targetUserId,
          },
        );

        final requestId = requestResult.first.toColumnMap()['id'];

        // Notify the owner of the private account.
        await session.execute(
          Sql.named('''
            INSERT INTO public.notifications (
              recipient_user_id,
              actor_user_id,
              notification_type
            )
            VALUES (
              @targetUserId,
              @actorUserId,
              'follow_request'
            )
          '''),
          parameters: {
            'targetUserId': targetUserId,
            'actorUserId': actorUserId,
          },
        );

        return {
          'status': 'request_created',
          'follow_request_id': requestId,
        };
      }

      // Public account: create the follow relationship immediately.
      final followInsertResult = await session.execute(
        Sql.named('''
          INSERT INTO public.user_follows (
            follower_user_id,
            following_user_id
          )
          VALUES (
            @actorUserId,
            @targetUserId
          )
          ON CONFLICT (
            follower_user_id,
            following_user_id
          ) DO NOTHING
          RETURNING follower_user_id
        '''),
        parameters: {
          'actorUserId': actorUserId,
          'targetUserId': targetUserId,
        },
      );

      if (followInsertResult.isEmpty) {
        return {
          'status': 'already_following',
        };
      }

      // Notify the followed account.
      await session.execute(
        Sql.named('''
          INSERT INTO public.notifications (
            recipient_user_id,
            actor_user_id,
            notification_type
          )
          VALUES (
            @targetUserId,
            @actorUserId,
            'user_follow'
          )
        '''),
        parameters: {
          'targetUserId': targetUserId,
          'actorUserId': actorUserId,
        },
      );

      return {
        'status': 'following',
      };
    });
  }

  /// Accepts a pending follow request.
  ///
  /// The target user must be the authenticated user.
  /// The follow relationship and acceptance notification are created
  /// atomically.

  Future<Map<String, dynamic>> acceptFollowRequest({
    required int requestId,
    required int targetUserId,
  }) async {
    if (requestId < 1 || targetUserId < 1) {
      throw ArgumentError('IDs must be positive.');
    }

    return database.runTx((session) async {
      final requestResult = await session.execute(
        Sql.named('''
          SELECT
            id,
            requester_user_id,
            target_user_id,
            status
          FROM public.follow_requests
          WHERE id = @requestId
            AND target_user_id = @targetUserId
          LIMIT 1
          FOR UPDATE
        '''),
        parameters: {
          'requestId': requestId,
          'targetUserId': targetUserId,
        },
      );

      if (requestResult.isEmpty) {
        return {'status': 'not_found'};
      }

      final request = requestResult.first.toColumnMap();

      if (request['status'] != 'pending') {
        return {'status': 'not_pending'};
      }

      final requesterId = _toInt(request['requester_user_id']);

      final blockResult = await session.execute(
        Sql.named('''
          SELECT EXISTS (
            SELECT 1
            FROM public.user_blocks
            WHERE (
              blocker_user_id = @requesterId
              AND blocked_user_id = @targetUserId
            )
            OR (
              blocker_user_id = @targetUserId
              AND blocked_user_id = @requesterId
            )
          )
        '''),
        parameters: {
          'requesterId': requesterId,
          'targetUserId': targetUserId,
        },
      );

      if (blockResult.first[0] == true) {
        return {'status': 'blocked'};
      }

      await session.execute(
        Sql.named('''
          INSERT INTO public.user_follows (
            follower_user_id,
            following_user_id
          )
          VALUES (
            @requesterId,
            @targetUserId
          )
          ON CONFLICT (
            follower_user_id,
            following_user_id
          ) DO NOTHING
        '''),
        parameters: {
          'requesterId': requesterId,
          'targetUserId': targetUserId,
        },
      );

      await session.execute(
        Sql.named('''
          UPDATE public.follow_requests
          SET
            status = 'accepted',
            updated_at = CURRENT_TIMESTAMP,
            responded_at = CURRENT_TIMESTAMP
          WHERE id = @requestId
        '''),
        parameters: {'requestId': requestId},
      );

      await session.execute(
        Sql.named('''
          INSERT INTO public.notifications (
            recipient_user_id,
            actor_user_id,
            notification_type
          )
          VALUES (
            @requesterId,
            @targetUserId,
            'follow_request_accepted'
          )
        '''),
        parameters: {
          'requesterId': requesterId,
          'targetUserId': targetUserId,
        },
      );

      return {
        'status': 'accepted',
        'requester_user_id': requesterId,
      };
    });
  }

  /// Rejects a pending follow request.
  Future<Map<String, dynamic>> rejectFollowRequest({
    required int requestId,
    required int targetUserId,
  }) async {
    if (requestId < 1 || targetUserId < 1) {
      throw ArgumentError('IDs must be positive.');
    }

    return database.runTx((session) async {
      final result = await session.execute(
        Sql.named('''
          UPDATE public.follow_requests
          SET
            status = 'rejected',
            updated_at = CURRENT_TIMESTAMP,
            responded_at = CURRENT_TIMESTAMP
          WHERE id = @requestId
            AND target_user_id = @targetUserId
            AND status = 'pending'
          RETURNING id
        '''),
        parameters: {
          'requestId': requestId,
          'targetUserId': targetUserId,
        },
      );

      if (result.isEmpty) {
        final exists = await session.execute(
          Sql.named('''
            SELECT status
            FROM public.follow_requests
            WHERE id = @requestId
              AND target_user_id = @targetUserId
            LIMIT 1
          '''),
          parameters: {
            'requestId': requestId,
            'targetUserId': targetUserId,
          },
        );

        if (exists.isEmpty) {
          return {'status': 'not_found'};
        }

        return {'status': 'not_pending'};
      }

      return {'status': 'rejected'};
    });
  }

  /// Cancels a pending follow request created by the requester.
  Future<Map<String, dynamic>> cancelFollowRequest({
    required int requestId,
    required int requesterUserId,
  }) async {
    if (requestId < 1 || requesterUserId < 1) {
      throw ArgumentError('IDs must be positive.');
    }

    return database.runTx((session) async {
      final result = await session.execute(
        Sql.named('''
          UPDATE public.follow_requests
          SET
            status = 'cancelled',
            updated_at = CURRENT_TIMESTAMP,
            responded_at = CURRENT_TIMESTAMP
          WHERE id = @requestId
            AND requester_user_id = @requesterUserId
            AND status = 'pending'
          RETURNING id
        '''),
        parameters: {
          'requestId': requestId,
          'requesterUserId': requesterUserId,
        },
      );

      if (result.isEmpty) {
        final exists = await session.execute(
          Sql.named('''
            SELECT status
            FROM public.follow_requests
            WHERE id = @requestId
              AND requester_user_id = @requesterUserId
            LIMIT 1
          '''),
          parameters: {
            'requestId': requestId,
            'requesterUserId': requesterUserId,
          },
        );

        if (exists.isEmpty) {
          return {'status': 'not_found'};
        }

        return {'status': 'not_pending'};
      }

      return {'status': 'cancelled'};
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is BigInt) return value.toInt();

    return int.parse(value.toString());
  }
}
