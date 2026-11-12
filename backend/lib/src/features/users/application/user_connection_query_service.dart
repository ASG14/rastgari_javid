import 'package:backend/src/features/users/data/user_connection_query_repository.dart';

/// Represents a follower or following query error.
class UserConnectionQueryException implements Exception {
  /// Creates a connection query exception.
  const UserConnectionQueryException(
    this.message, {
    this.statusCode = 400,
  });

  /// User-facing error message.
  final String message;

  /// HTTP status code.
  final int statusCode;

  @override
  String toString() => message;
}

/// Handles follower and following queries.
class UserConnectionQueryService {
  /// Creates the service.
  UserConnectionQueryService(this._repository);

  final UserConnectionQueryRepository _repository;

  /// Returns a paginated list of followers or following accounts.
  Future<Map<String, dynamic>> getConnections({
    required int viewerUserId,
    required int targetUserId,
    required bool followers,
    int limit = 20,
    int offset = 0,
  }) async {
    if (viewerUserId < 1) {
      throw const UserConnectionQueryException(
        'اطلاعات حساب کاربری معتبر نیست.',
        statusCode: 401,
      );
    }

    if (targetUserId < 1) {
      throw const UserConnectionQueryException(
        'شناسه کاربر مقصد معتبر نیست.',
      );
    }

    if (limit < 1 || limit > 100) {
      throw const UserConnectionQueryException(
        'تعداد نتایج باید بین ۱ تا ۱۰۰ باشد.',
      );
    }

    if (offset < 0) {
      throw const UserConnectionQueryException(
        'مقدار شروع صفحه‌بندی معتبر نیست.',
      );
    }

    final result = await _repository.getConnections(
      viewerUserId: viewerUserId,
      targetUserId: targetUserId,
      followers: followers,
      limit: limit,
      offset: offset,
    );

    switch (result['status']) {
      case 'found':
        return result['data'] as Map<String, dynamic>;

      case 'private':
        throw const UserConnectionQueryException(
          'برای مشاهده این فهرست ابتدا باید کاربر را دنبال کنید.',
          statusCode: 403,
        );

      case 'not_found':
        throw const UserConnectionQueryException(
          'کاربر موردنظر یافت نشد.',
          statusCode: 404,
        );

      default:
        throw const UserConnectionQueryException(
          'دریافت فهرست ارتباطات کاربران با خطا مواجه شد.',
          statusCode: 500,
        );
    }
  }
}
