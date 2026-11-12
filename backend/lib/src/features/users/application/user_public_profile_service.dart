import 'package:backend/src/features/users/data/user_public_profile_repository.dart';

/// Handles public user profile operations.
class UserPublicProfileService {
  /// Creates a public profile service.
  UserPublicProfileService(this._repository);

  final UserPublicProfileRepository _repository;

  /// Retrieves a public profile for the authenticated viewer.
  Future<Map<String, dynamic>> getPublicProfile({
    required int viewerUserId,
    required int targetUserId,
  }) async {
    if (viewerUserId < 1) {
      throw const UserPublicProfileException(
        'اطلاعات کاربر احراز هویت‌شده معتبر نیست.',
        statusCode: 401,
      );
    }

    if (targetUserId < 1) {
      throw const UserPublicProfileException(
        'شناسه کاربر مقصد معتبر نیست.',
      );
    }

    final result = await _repository.getPublicProfile(
      viewerUserId: viewerUserId,
      targetUserId: targetUserId,
    );

    if (result == null || result['status'] == 'blocked') {
      throw const UserPublicProfileException(
        'کاربر موردنظر یافت نشد.',
        statusCode: 404,
      );
    }

    return result['profile'] as Map<String, dynamic>;
  }
}

/// Represents a public user profile error.
class UserPublicProfileException implements Exception {
  /// Creates a public profile exception.
  const UserPublicProfileException(
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
