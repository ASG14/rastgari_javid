
import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles database operations for user-to-user relationships.
class UserRelationshipRepository {
  /// Creates a follow relationship or a follow request.
  ///
  /// Public accounts are followed immediately.
  /// Private accounts receive a pending follow request.
  ///
  /// Both accounts are locked in ascending ID order to serialize
  /// concurrent relationship operations.
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
      final users = await _lockUsers(
        session,
        firstUserId: actorUserId,
        secondUserId: targetUserId,
      );

      final actor = users[actorUserId];
      final target = users[targetUserId];

      if (actor == null || !_isActive(actor)) {
        return {'status': 'actor_not_found'};
      }

      if (target == null || !_isActive(target)) {
        return {'status': 'target_not_found'};
      }

      final isPrivate = target['is_private'] as bool;

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
        return {'status': 'blocked'};
      }

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
        return {'status': 'already_following'};
      }

      if (isPrivate) {
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
        return {'status': 'already_following'};
      }

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

      return {'status': 'following'};
    });
  }


  /// Removes the authenticated user's follow relationship with another user.
  ///
  /// Both accounts are locked in ascending ID order to serialize
  /// concurrent relationship operations.
  Future<Map<String, dynamic>> unfollowUser({
    required int actorUserId,
    required int targetUserId,
  }) {
    if (actorUserId < 1 || targetUserId < 1) {
      throw ArgumentError('User IDs must be positive.');
    }

    if (actorUserId == targetUserId) {
      throw ArgumentError('A user cannot unfollow themselves.');
    }

    return database.runTx((session) async {
      final users = await _lockUsers(
        session,
        firstUserId: actorUserId,
        secondUserId: targetUserId,
      );

      final actor = users[actorUserId];
      final target = users[targetUserId];

      if (actor == null || !_isActive(actor)) {
        return {'status': 'actor_not_found'};
      }

      if (target == null || !_isActive(target)) {
        return {'status': 'target_not_found'};
      }

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
        return {'status': 'blocked'};
      }

      final result = await session.execute(
        Sql.named('''
          DELETE FROM public.user_follows
          WHERE follower_user_id = @actorUserId
            AND following_user_id = @targetUserId
          RETURNING follower_user_id
        '''),
        parameters: {
          'actorUserId': actorUserId,
          'targetUserId': targetUserId,
        },
      );

      if (result.isEmpty) {
        return {'status': 'not_following'};
      }

      return {'status': 'unfollowed'};
    });
  }

 
  Future<Map<String, dynamic>> acceptFollowRequest({
    required int requestId,
    required int targetUserId,
  }) async {
    if (requestId < 1 || targetUserId < 1) {
      throw ArgumentError('IDs must be positive.');
    }

    return database.runTx((session) async {
      // Read the requester ID first without locking the request row.
      // This lets us acquire account locks before the request lock.
      final initialRequestResult = await session.execute(
        Sql.named('''
          SELECT requester_user_id
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

      if (initialRequestResult.isEmpty) {
        return {'status': 'not_found'};
      }

      final requesterId = _toInt(
        initialRequestResult.first.toColumnMap()['requester_user_id'],
      );

      if (requesterId == targetUserId) {
        return {'status': 'not_found'};
      }

      final users = await _lockUsers(
        session,
        firstUserId: requesterId,
        secondUserId: targetUserId,
      );

      final requester = users[requesterId];
      final target = users[targetUserId];

      if (requester == null || !_isActive(requester)) {
        return {'status': 'requester_not_found'};
      }

      if (target == null || !_isActive(target)) {
        return {'status': 'target_not_found'};
      }

      // Re-read and lock the request after acquiring both account locks.
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

      if (_toInt(request['requester_user_id']) != requesterId) {
        return {'status': 'not_found'};
      }

      if (request['status'] != 'pending') {
        return {'status': 'not_pending'};
      }

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

  /// Locks two user rows in ascending ID order.
  ///
  /// Returns the existing rows keyed by user ID.
  /// Inactive users are included so their status can be checked
  /// after the locks have been acquired.
  Future<Map<int, Map<String, dynamic>>> _lockUsers(
    Session session, {
    required int firstUserId,
    required int secondUserId,
  }) async {
    final firstId = firstUserId < secondUserId
        ? firstUserId
        : secondUserId;
    final secondId = firstUserId < secondUserId
        ? secondUserId
        : firstUserId;

    final result = await session.execute(
      Sql.named('''
        SELECT
          id,
          is_private,
          status,
          deleted_at
        FROM public.users
        WHERE id IN (@firstUserId, @secondUserId)
        ORDER BY id ASC
        FOR UPDATE
      '''),
      parameters: {
        'firstUserId': firstId,
        'secondUserId': secondId,
      },
    );

    final users = <int, Map<String, dynamic>>{};

    for (final row in result) {
      final user = row.toColumnMap();
      users[_toInt(user['id'])] = user;
    }

    return users;
  }

  bool _isActive(Map<String, dynamic> user) {
    return user['deleted_at'] == null && user['status'] == 'active';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is BigInt) return value.toInt();

    return int.parse(value.toString());
  }
}
