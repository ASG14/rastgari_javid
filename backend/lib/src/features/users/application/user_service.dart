import 'package:backend/src/features/users/data/user_repository.dart';

/// Represents a profile-related validation error.
class UserException implements Exception {
  /// Creates a profile validation exception.
  const UserException(
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

/// Handles user profile operations and validation.
class UserService {
  /// Creates a user service with the provided repository.
  UserService(this._repository);

  final UserRepository _repository;

  /// Updates the authenticated user's profile.
  ///
  /// Omitted fields remain unchanged. Sending `bio: null` clears the bio.
  Future<Map<String, dynamic>> updateProfile({
    required int userId,
    String? username,
    String? displayName,
    bool updateBio = false,
    String? bio,
  }) async {
    if (userId < 1) {
      throw const UserException(
        'شناسه کاربر معتبر نیست.',
        statusCode: 401,
      );
    }

    final normalizedUsername = username?.trim();
    final normalizedDisplayName = displayName?.trim();
    final normalizedBio = bio?.trim();

    if (normalizedUsername != null) {
      if (!RegExp(r'^[A-Za-z0-9_]{3,30}$').hasMatch(normalizedUsername)) {
        throw const UserException(
          'نام کاربری باید ۳ تا ۳۰ کاراکتر و شامل \n حروف انگلیسی، عدد یا زیرخط باشد.',
        );
      }

      if (await _repository.usernameExists(
        username: normalizedUsername,
        excludingUserId: userId,
      )) {
        throw const UserException(
          'این نام کاربری قبلاً ثبت شده است.',
          statusCode: 409,
        );
      }
    }

    if (normalizedDisplayName != null &&
        (normalizedDisplayName.isEmpty || normalizedDisplayName.length > 100)) {
      throw const UserException(
        'نام نمایشی باید بین ۱ تا ۱۰۰ کاراکتر باشد.',
      );
    }

    if (updateBio && normalizedBio != null && normalizedBio.length > 500) {
      throw const UserException(
        'توضیحات پروفایل نمی‌تواند بیشتر از ۵۰۰ کاراکتر باشد.',
      );
    }

    // Fetch current data through a profile update that preserves omitted
    // fields. The repository needs the current values for PATCH semantics.
    final currentProfile = await _repository.getProfile(userId);

    if (currentProfile == null) {
      throw const UserException(
        'کاربر موردنظر یافت نشد یا حساب او فعال نیست.',
        statusCode: 404,
      );
    }

    final updatedProfile = await _repository.updateProfile(
      userId: userId,
      username: normalizedUsername ?? currentProfile['username'] as String,
      displayName:
          normalizedDisplayName ?? currentProfile['display_name'] as String,
      updateBio: updateBio,
      bio: normalizedBio,
    );

    if (updatedProfile == null) {
      throw const UserException(
        'به‌روزرسانی پروفایل انجام نشد.',
        statusCode: 404,
      );
    }

    return updatedProfile;
  }
}
