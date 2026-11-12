
import 'package:backend/src/features/users/data/user_block_repository.dart';

/// Represents a user blocking operation error.
class UserBlockException implements Exception {
  /// Creates a blocking exception.
  const UserBlockException(
    this.message, {
    this.statusCode = 400,
  });

  /// User-facing error message.
  final String message;

  /// HTTP status code associated with the error.
  final int statusCode;

  @override
  String toString() => message;
}

/// Handles user blocking operations and their business rules.
class UserBlockService {
  /// Creates a blocking service.
  UserBlockService(this._repository);

  final UserBlockRepository _repository;

  /// Blocks another user.
  Future<Map<String, dynamic>> blockUser({
    required int blockerUserId,
    required int blockedUserId,
  }) async {
    _validateIds(blockerUserId, blockedUserId);

    final result = await _repository.blockUser(
      blockerUserId: blockerUserId,
      blockedUserId: blockedUserId,
    );

    switch (result['status']) {
      case 'blocked':
        return {
          'status': 'blocked',
          'message': 'کاربر با موفقیت مسدود شد.',
        };

      case 'already_blocked':
        return {
          'status': 'already_blocked',
          'message': 'این کاربر قبلاً مسدود شده است.',
        };

      case 'user_not_found':
        throw const UserBlockException(
          'کاربر موردنظر یافت نشد یا حساب او فعال نیست.',
          statusCode: 404,
        );

      default:
        throw const UserBlockException(
          'در مسدودسازی کاربر خطایی رخ داد.',
          statusCode: 500,
        );
    }
  }

  /// Removes a block placed by the authenticated user.
  Future<Map<String, dynamic>> unblockUser({
    required int blockerUserId,
    required int blockedUserId,
  }) async {
    _validateIds(blockerUserId, blockedUserId);

    final result = await _repository.unblockUser(
      blockerUserId: blockerUserId,
      blockedUserId: blockedUserId,
    );

    switch (result['status']) {
      case 'unblocked':
        return {
          'status': 'unblocked',
          'message': 'مسدودیت کاربر برداشته شد.',
        };

      case 'not_blocked':
        throw const UserBlockException(
          'این کاربر در فهرست مسدودشده‌های شما نیست.',
          statusCode: 404,
        );

      case 'user_not_found':
        throw const UserBlockException(
          'کاربر موردنظر یافت نشد یا حساب او فعال نیست.',
          statusCode: 404,
        );

      default:
        throw const UserBlockException(
          'در رفع مسدودیت کاربر خطایی رخ داد.',
          statusCode: 500,
        );
    }
  }

  void _validateIds(int actorId, int targetId) {
    if (actorId < 1) {
      throw const UserBlockException(
        'کاربر احراز هویت نشده است.',
        statusCode: 401,
      );
    }

    if (targetId < 1) {
      throw const UserBlockException(
        'شناسه کاربر مقصد معتبر نیست.',
      );
    }

    if (actorId == targetId) {
      throw const UserBlockException(
        'امکان مسدودسازی حساب خودتان وجود ندارد.',
      );
    }
  }
}
