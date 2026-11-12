import 'package:backend/src/features/users/data/user_relationship_repository.dart';

/// Represents a user relationship operation error.
class UserRelationshipException implements Exception {
  /// Creates a relationship exception.
  const UserRelationshipException(
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

/// Handles user relationship operations and their business rules.
class UserRelationshipService {
  /// Creates a relationship service with the provided repository.
  UserRelationshipService(this._repository);

  final UserRelationshipRepository _repository;

  /// Follows a user or creates a follow request for a private account.
  ///
  /// The authenticated user's ID must be supplied as [actorUserId].
  Future<Map<String, dynamic>> followUser({
    required int actorUserId,
    required int targetUserId,
  }) async {
    if (actorUserId < 1) {
      throw const UserRelationshipException(
        'کاربر احراز هویت نشده است.',
        statusCode: 401,
      );
    }

    if (targetUserId < 1) {
      throw const UserRelationshipException(
        'شناسه کاربر مقصد معتبر نیست.',
      );
    }

    if (actorUserId == targetUserId) {
      throw const UserRelationshipException(
        'امکان دنبال کردن حساب خودتان وجود ندارد.',
      );
    }

    final result = await _repository.followUser(
      actorUserId: actorUserId,
      targetUserId: targetUserId,
    );

    final status = result['status'];

    switch (status) {
      case 'following':
        return {
          'status': 'following',
          'message': 'حساب کاربر با موفقیت دنبال شد.',
        };

      case 'request_created':
        return {
          'status': 'request_created',
          'message': 'درخواست دنبال کردن ارسال شد.',
          'follow_request_id': result['follow_request_id'],
        };

      case 'already_following':
        return {
          'status': 'already_following',
          'message': 'شما در حال حاضر این کاربر را دنبال می‌کنید.',
        };

      case 'request_already_pending':
        return {
          'status': 'request_already_pending',
          'message': 'درخواست دنبال کردن شما هنوز در انتظار تأیید است.',
          'follow_request_id': result['follow_request_id'],
        };

      case 'incoming_request_pending':
        throw const UserRelationshipException(
          'از این کاربر یک درخواست دنبال کردن دریافت کرده‌اید.\n ابتدا آن را بررسی کنید.',
          statusCode: 409,
        );

      case 'actor_not_found':
        throw const UserRelationshipException(
          'حساب کاربری شما معتبر یا فعال نیست.',
          statusCode: 401,
        );

      case 'target_not_found':
        throw const UserRelationshipException(
          'کاربر موردنظر یافت نشد یا حساب او فعال نیست.',
          statusCode: 404,
        );

      case 'blocked':
        throw const UserRelationshipException(
          'به دلیل محدودیت ارتباطی، امکان دنبال کردن این کاربر وجود ندارد.',
          statusCode: 403,
        );

      default:
        throw const UserRelationshipException(
          'در انجام عملیات دنبال کردن کاربر خطایی رخ داد.',
          statusCode: 500,
        );
    }
  }

  /// Removes the authenticated user's follow relationship with another user.

  /// Removes the authenticated user's follow relationship with another user.
  Future<Map<String, dynamic>> unfollowUser({
    required int actorUserId,
    required int targetUserId,
  }) async {
    if (actorUserId < 1) {
      throw const UserRelationshipException(
        'کاربر احراز هویت نشده است.',
        statusCode: 401,
      );
    }

    if (targetUserId < 1) {
      throw const UserRelationshipException(
        'شناسه کاربر مقصد معتبر نیست.',
      );
    }

    if (actorUserId == targetUserId) {
      throw const UserRelationshipException(
        'امکان لغو دنبال‌کردن حساب خودتان وجود ندارد.',
      );
    }

    final result = await _repository.unfollowUser(
      actorUserId: actorUserId,
      targetUserId: targetUserId,
    );

    switch (result['status']) {
      case 'unfollowed':
        return {
          'status': 'unfollowed',
          'message': 'دنبال‌کردن این کاربر لغو شد.',
        };

      case 'not_following':
        return {
          'status': 'not_following',
          'message': 'شما در حال حاضر این کاربر را دنبال نمی‌کنید.',
        };

      case 'actor_not_found':
        throw const UserRelationshipException(
          'حساب کاربری شما معتبر یا فعال نیست.',
          statusCode: 401,
        );

      case 'target_not_found':
        throw const UserRelationshipException(
          'کاربر موردنظر یافت نشد یا حساب او فعال نیست.',
          statusCode: 404,
        );

      case 'blocked':
        throw const UserRelationshipException(
          'به دلیل محدودیت ارتباطی، امکان انجام این عملیات وجود ندارد.',
          statusCode: 403,
        );

      default:
        throw const UserRelationshipException(
          'در لغو دنبال‌کردن کاربر خطایی رخ داد.',
          statusCode: 500,
        );
    }
  }

  Future<Map<String, dynamic>> acceptFollowRequest({
    required int targetUserId,
    required int requestId,
  }) async {
    if (targetUserId < 1 || requestId < 1) {
      throw const UserRelationshipException(
        'اطلاعات درخواست معتبر نیست.',
      );
    }

    final result = await _repository.acceptFollowRequest(
      requestId: requestId,
      targetUserId: targetUserId,
    );

    switch (result['status']) {
      case 'accepted':
        return {
          'status': 'accepted',
          'message': 'درخواست دنبال کردن پذیرفته شد.',
        };

      case 'not_found':
        throw const UserRelationshipException(
          'درخواست موردنظر یافت نشد.',
          statusCode: 404,
        );

      case 'not_pending':
        throw const UserRelationshipException(
          'این درخواست قبلاً تعیین تکلیف شده است.',
          statusCode: 409,
        );

      case 'blocked':
        throw const UserRelationshipException(
          'به دلیل محدودیت ارتباطی، امکان پذیرش درخواست وجود ندارد.',
          statusCode: 403,
        );

      default:
        throw const UserRelationshipException(
          'پذیرش درخواست انجام نشد.',
          statusCode: 500,
        );
    }
  }

  /// Rejects a follow request received by the authenticated user.
  Future<Map<String, dynamic>> rejectFollowRequest({
    required int targetUserId,
    required int requestId,
  }) async {
    if (targetUserId < 1 || requestId < 1) {
      throw const UserRelationshipException(
        'اطلاعات درخواست معتبر نیست.',
      );
    }

    final result = await _repository.rejectFollowRequest(
      requestId: requestId,
      targetUserId: targetUserId,
    );

    switch (result['status']) {
      case 'rejected':
        return {
          'status': 'rejected',
          'message': 'درخواست دنبال کردن رد شد.',
        };

      case 'not_found':
        throw const UserRelationshipException(
          'درخواست موردنظر یافت نشد.',
          statusCode: 404,
        );

      case 'not_pending':
        throw const UserRelationshipException(
          'این درخواست قبلاً تعیین تکلیف شده است.',
          statusCode: 409,
        );

      default:
        throw const UserRelationshipException(
          'رد درخواست انجام نشد.',
          statusCode: 500,
        );
    }
  }

  /// Cancels a follow request created by the authenticated user.
  Future<Map<String, dynamic>> cancelFollowRequest({
    required int requesterUserId,
    required int requestId,
  }) async {
    if (requesterUserId < 1 || requestId < 1) {
      throw const UserRelationshipException(
        'اطلاعات درخواست معتبر نیست.',
      );
    }

    final result = await _repository.cancelFollowRequest(
      requestId: requestId,
      requesterUserId: requesterUserId,
    );

    switch (result['status']) {
      case 'cancelled':
        return {
          'status': 'cancelled',
          'message': 'درخواست دنبال کردن لغو شد.',
        };

      case 'not_found':
        throw const UserRelationshipException(
          'درخواست موردنظر یافت نشد.',
          statusCode: 404,
        );

      case 'not_pending':
        throw const UserRelationshipException(
          'این درخواست قبلاً تعیین تکلیف شده است.',
          statusCode: 409,
        );

      default:
        throw const UserRelationshipException(
          'لغو درخواست انجام نشد.',
          statusCode: 500,
        );
    }
  }
}
