import 'package:backend/src/features/users/data/user_block_query_repository.dart';

/// Represents a blocked-user listing error.
class UserBlockQueryException implements Exception {
  /// Creates a blocked-user listing exception.
  const UserBlockQueryException(
    this.message, {
    this.statusCode = 400,
  });

  /// User-facing error message.
  final String message;

  /// HTTP status code associated with this error.
  final int statusCode;

  @override
  String toString() => message;
}

/// Handles blocked-user listing and pagination validation.
class UserBlockQueryService {
  /// Creates the service.
  UserBlockQueryService(this._repository);

  final UserBlockQueryRepository _repository;

  /// Returns the authenticated user's blocked users.
  Future<Map<String, dynamic>> getBlockedUsers({
    required int userId,
    int limit = 20,
    int offset = 0,
  }) async {
    if (userId < 1) {
      throw const UserBlockQueryException(
        'شناسه کاربر معتبر نیست.',
        statusCode: 401,
      );
    }

    if (limit < 1 || limit > 100) {
      throw const UserBlockQueryException(
        'تعداد نتایج باید بین ۱ تا ۱۰۰ باشد.',
      );
    }

    if (offset < 0) {
      throw const UserBlockQueryException(
        'مقدار شروع صفحه‌بندی معتبر نیست.',
      );
    }

    return _repository.getBlockedUsers(
      userId: userId,
      limit: limit,
      offset: offset,
    );
  }
}
