import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles database queries for public user profiles.
class UserPublicProfileRepository {
  /// Retrieves a user's public profile and relationship state.
  ///
  /// Returns null when the target user does not exist or is inactive.
  Future<Map<String, dynamic>?> getPublicProfile({
    required int viewerUserId,
    required int targetUserId,
  }) async {
    final result = await database.execute(
      Sql.named('''
        SELECT
          u.id,
          u.username,
          u.display_name,
          u.bio,
          u.avatar_storage_key,
          u.is_private,
          u.created_at,

          (
            SELECT COUNT(*)
            FROM public.user_follows AS f
            INNER JOIN public.users AS follower
              ON follower.id = f.follower_user_id
            WHERE f.following_user_id = u.id
              AND follower.status = 'active'
              AND follower.deleted_at IS NULL
          ) AS followers_count,

          (
            SELECT COUNT(*)
            FROM public.user_follows AS f
            INNER JOIN public.users AS following
              ON following.id = f.following_user_id
            WHERE f.follower_user_id = u.id
              AND following.status = 'active'
              AND following.deleted_at IS NULL
          ) AS following_count,

          EXISTS (
            SELECT 1
            FROM public.user_follows
            WHERE follower_user_id = @viewerUserId
              AND following_user_id = u.id
          ) AS is_following,

          EXISTS (
            SELECT 1
            FROM public.user_follows
            WHERE follower_user_id = u.id
              AND following_user_id = @viewerUserId
          ) AS is_followed_by,

          EXISTS (
            SELECT 1
            FROM public.follow_requests
            WHERE requester_user_id = @viewerUserId
              AND target_user_id = u.id
              AND status = 'pending'
          ) AS has_pending_follow_request,

          EXISTS (
            SELECT 1
            FROM public.follow_requests
            WHERE requester_user_id = u.id
              AND target_user_id = @viewerUserId
              AND status = 'pending'
          ) AS has_incoming_follow_request,

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

    if (result.isEmpty) return null;

    final data = result.first.toColumnMap();

    if (data['is_blocked'] == true) {
      return {
        'status': 'blocked',
      };
    }

    final isPrivate = data['is_private'] == true;
    final isFollowing = data['is_following'] == true;

    final isOwnProfile = viewerUserId == targetUserId;

    final canViewPosts = isOwnProfile || !isPrivate || isFollowing;

    return {
      'status': 'found',
      'profile': {
        'id': _toInt(data['id']),
        'username': data['username'],
        'display_name': data['display_name'],
        'bio': data['bio'],
        'avatar_storage_key': data['avatar_storage_key'],
        'is_private': isPrivate,
        'created_at': data['created_at']?.toString(),
        'followers_count': _toInt(data['followers_count']),
        'following_count': _toInt(data['following_count']),
        'can_view_posts': canViewPosts,
        'relationship': {
          'is_following': isFollowing,
          'is_followed_by': data['is_followed_by'] == true,
          'has_pending_follow_request':
              data['has_pending_follow_request'] == true,
          'has_incoming_follow_request':
              data['has_incoming_follow_request'] == true,
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
