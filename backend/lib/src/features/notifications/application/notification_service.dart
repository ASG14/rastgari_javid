import 'package:backend/src/features/notifications/data/notification_repository.dart';

/// Handles application logic for user notifications.
class NotificationService {
  NotificationService(this._repository);

  final NotificationRepository _repository;

  /// Returns the latest notifications belonging to a user.
  Future<List<Map<String, dynamic>>> getNotifications({
    required int userId,
    int limit = 50,
  }) {
    _validateUserId(userId);

    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(
        limit,
        'limit',
        'The limit must be between 1 and 100.',
      );
    }

    return _repository.getNotifications(
      userId: userId,
      limit: limit,
    );
  }

  /// Returns the number of unread notifications belonging to a user.
  Future<int> getUnreadCount({required int userId}) {
    _validateUserId(userId);

    return _repository.getUnreadCount(userId: userId);
  }

  /// Marks all unread notifications belonging to a user as read.
  Future<int> markAllAsRead({required int userId}) {
    _validateUserId(userId);

    return _repository.markAllAsRead(userId: userId);
  }

  /// Marks a notification as read if it belongs to the specified user.
  ///
  /// Returns false if the notification does not exist or belongs to
  /// another user.
  Future<bool> markAsRead({
    required int notificationId,
    required int userId,
  }) {
    _validateUserId(userId);

    if (notificationId < 1) {
      throw ArgumentError.value(
        notificationId,
        'notificationId',
        'The notification ID must be positive.',
      );
    }

    return _repository.markAsRead(
      notificationId: notificationId,
      userId: userId,
    );
  }

  void _validateUserId(int userId) {
    if (userId < 1) {
      throw ArgumentError.value(
        userId,
        'userId',
        'The user ID must be positive.',
      );
    }
  }
}
