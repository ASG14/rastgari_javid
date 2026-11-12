import 'package:backend/src/features/users/data/follow_request_query_repository.dart';

/// Represents a follow request query error.
class FollowRequestQueryException implements Exception {
  /// Creates a follow request query exception.
  const FollowRequestQueryException(
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

/// Handles incoming and outgoing follow request queries.
class FollowRequestQueryService {
  /// Creates the service.
  FollowRequestQueryService(this._repository);

  final FollowRequestQueryRepository _repository;

  /// Returns a paginated list of follow requests.
  Future<Map<String, dynamic>> getRequests({
    required int userId,
    required bool incoming,
    int limit = 20,
    int offset = 0,
  }) async {
    if (userId < 1) {
      throw const FollowRequestQueryException(
        'اطلاعات حساب کاربری معتبر نیست.',
        statusCode: 401,
      );
    }

    if (limit < 1 || limit > 100) {
      throw const FollowRequestQueryException(
        'تعداد نتایج باید بین ۱ تا ۱۰۰ باشد.',
      );
    }

    if (offset < 0) {
      throw const FollowRequestQueryException(
        'مقدار شروع صفحه‌بندی معتبر نیست.',
      );
    }

    return _repository.getRequests(
      userId: userId,
      incoming: incoming,
      limit: limit,
      offset: offset,
    );
  }
}
