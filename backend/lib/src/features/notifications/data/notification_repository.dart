import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

/// Handles database operations for user notifications.
class NotificationRepository {
  /// Returns the latest notifications belonging to a user.
  Future<List<Map<String, dynamic>>> getNotifications({
    required int userId,
    int limit = 50,
  }) async {
    final safeLimit = limit.clamp(1, 100);

    final result = await database.execute(
      Sql.named('''
        SELECT
          n.id,
          n.notification_type,
          n.post_id,
          n.comment_id,
          n.created_at,
          n.read_at,
          LEFT(
            CASE
              WHEN n.notification_type = 'post_like'
                THEN p.content
              ELSE c.content
            END,
            140
          ) AS content_preview,
          actor.id AS actor_id,
          actor.username AS actor_username,
          actor.display_name AS actor_display_name
        FROM public.notifications AS n
        LEFT JOIN public.users AS actor
          ON actor.id = n.actor_user_id
        LEFT JOIN public.posts AS p
          ON p.id = n.post_id
        LEFT JOIN public.comments AS c
          ON c.id = n.comment_id
        WHERE n.recipient_user_id = @userId
        ORDER BY n.created_at DESC, n.id DESC
        LIMIT @limit
      '''),
      parameters: {
        'userId': userId,
        'limit': safeLimit,
      },
    );

    return result.map((row) {
      final data = row.toColumnMap();

      return {
        'id': data['id'],
        'type': data['notification_type'],
        'post_id': data['post_id'],
        'comment_id': data['comment_id'],
        'created_at': data['created_at']?.toString(),
        'read_at': data['read_at']?.toString(),
        'content_preview': data['content_preview'],
        'actor': data['actor_id'] == null
            ? null
            : {
                'id': data['actor_id'],
                'username': data['actor_username'],
                'display_name': data['actor_display_name'],
              },
        'is_read': data['read_at'] != null,
      };
    }).toList();
  }

  /// Returns the number of unread notifications belonging to a user.
  Future<int> getUnreadCount({required int userId}) async {
    final result = await database.execute(
      Sql.named('''
        SELECT COUNT(*) AS unread_count
        FROM public.notifications
        WHERE recipient_user_id = @userId
          AND read_at IS NULL
      '''),
      parameters: {'userId': userId},
    );

    final count = result.first.toColumnMap()['unread_count'];

    if (count is int) return count;
    if (count is BigInt) return count.toInt();

    return int.parse(count.toString());
  }

  /// Marks all unread notifications belonging to a user as read.
  ///
  /// Returns the number of notifications that were updated.
  Future<int> markAllAsRead({required int userId}) async {
    final result = await database.execute(
      Sql.named('''
        UPDATE public.notifications
        SET read_at = CURRENT_TIMESTAMP
        WHERE recipient_user_id = @userId
          AND read_at IS NULL
        RETURNING id
      '''),
      parameters: {'userId': userId},
    );

    return result.length;
  }

  /// Marks one of the user's notifications as read.
  ///
  /// Returns false if the notification does not belong to the user
  /// or does not exist.
  Future<bool> markAsRead({
    required int notificationId,
    required int userId,
  }) async {
    final result = await database.execute(
      Sql.named('''
        UPDATE public.notifications
        SET read_at = CURRENT_TIMESTAMP
        WHERE id = @notificationId
          AND recipient_user_id = @userId
          AND read_at IS NULL
        RETURNING id
      '''),
      parameters: {
        'notificationId': notificationId,
        'userId': userId,
      },
    );

    if (result.isNotEmpty) return true;

    final existing = await database.execute(
      Sql.named('''
        SELECT id
        FROM public.notifications
        WHERE id = @notificationId
          AND recipient_user_id = @userId
        LIMIT 1
      '''),
      parameters: {
        'notificationId': notificationId,
        'userId': userId,
      },
    );

    return existing.isNotEmpty;
  }
}
