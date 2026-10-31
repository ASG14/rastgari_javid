import 'dart:io';

import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';

/// Represents an authentication-related business error.
class AuthException implements Exception {
  /// Creates an authentication exception with an HTTP status code.
  AuthException(this.message, {this.statusCode = 400});

  /// User-facing error message.
  final String message;

  /// HTTP status code associated with the error.
  final int statusCode;

  @override
  String toString() => message;
}

/// Handles registration, login, password hashing, and token generation.
class AuthService {
  /// Creates the authentication service with its repository.
  AuthService(this._repository);

  final AuthRepository _repository;

  /// Registers a new user and returns their public information.
  Future<Map<String, dynamic>> register({
    required String username,
    required String displayName,
    required String password,
    String? email,
  }) async {
    final normalizedUsername = username.trim();
    final normalizedDisplayName = displayName.trim();
    final normalizedEmail = email?.trim().toLowerCase();

    if (!RegExp(r'^[A-Za-z0-9_]{3,30}$').hasMatch(normalizedUsername)) {
      throw AuthException(
        // ignore: lines_longer_than_80_chars
        'نام کاربری باید ۳ تا ۳۰ کاراکتر و شامل حروف انگلیسی، عدد یا زیرخط باشد.',
      );
    }

    if (normalizedDisplayName.isEmpty || normalizedDisplayName.length > 100) {
      throw AuthException(
        'نام نمایشی الزامی است و حداکثر ۱۰۰ کاراکتر دارد.',
      );
    }

    if (password.length < 8 || password.length > 72) {
      throw AuthException('رمز عبور باید بین ۸ تا ۷۲ کاراکتر باشد.');
    }

    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedEmail)) {
        throw AuthException('فرمت ایمیل معتبر نیست.');
      }

      if (await _repository.emailExists(normalizedEmail)) {
        throw AuthException(
          'این ایمیل قبلاً ثبت شده است.',
          statusCode: 409,
        );
      }
    }

    if (await _repository.usernameExists(normalizedUsername)) {
      throw AuthException(
        'این نام کاربری قبلاً ثبت شده است.',
        statusCode: 409,
      );
    }

    final passwordHash = BCrypt.hashpw(password, BCrypt.gensalt());

    final user = await _repository.createUser(
      username: normalizedUsername,
      displayName: normalizedDisplayName,
      passwordHash: passwordHash,
      email: normalizedEmail == null || normalizedEmail.isEmpty
          ? null
          : normalizedEmail,
    );

    return _publicUser(user);
  }

  /// Authenticates a user and returns their JWT access token.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final user = await _repository.findByUsername(username.trim());

    if (user == null ||
        user['password_hash'] is! String ||
        !BCrypt.checkpw(password, user['password_hash'] as String)) {
      throw AuthException(
        'نام کاربری یا رمز عبور اشتباه است.',
        statusCode: 401,
      );
    }

    if (user['status'] != 'active') {
      throw AuthException(
        'این حساب کاربری فعال نیست.',
        statusCode: 403,
      );
    }

    final secret = Platform.environment['RJ_JWT_SECRET'];

    if (secret == null || secret.length < 32) {
      throw StateError(
        'RJ_JWT_SECRET must be configured with at least 32 characters.',
      );
    }

    final userId = user['id'] as int;

    final token =
        JWT({
          'sub': userId.toString(),
          'username': user['username'],
        }).sign(
          SecretKey(secret),
          expiresIn: const Duration(hours: 1),
        );

    await _repository.updateLastLogin(userId);

    return {
      'user': _publicUser(user),
      'access_token': token,
      'token_type': 'Bearer',
      'expires_in': 3600,
    };
  }

  Map<String, dynamic> _publicUser(Map<String, dynamic> user) {
    return {
      'id': user['id'],
      'username': user['username'],
      'display_name': user['display_name'],
      'email': user['email'],
      if (user['created_at'] != null)
        'created_at': user['created_at'].toString(),
    };
  }

  /// Verifies an access token and returns the current user's public data.
  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    final secret = Platform.environment['RJ_JWT_SECRET'];

    if (secret == null || secret.length < 32) {
      throw StateError(
        'RJ_JWT_SECRET must be configured with at least 32 characters.',
      );
    }

    late final Map<String, dynamic> payload;

    try {
      final jwt = JWT.verify(token, SecretKey(secret));
      final decodedPayload = jwt.payload;

      if (decodedPayload is! Map<String, dynamic>) {
        throw const FormatException('Invalid token payload.');
      }

      payload = decodedPayload;
    } catch (_) {
      throw AuthException(
        'توکن ورود نامعتبر یا منقضی شده است.',
        statusCode: 401,
      );
    }

    final userId = int.tryParse(payload['sub']?.toString() ?? '');

    if (userId == null) {
      throw AuthException(
        'توکن ورود معتبر نیست.',
        statusCode: 401,
      );
    }

    final user = await _repository.findById(userId);

    if (user == null) {
      throw AuthException(
        'کاربر موردنظر یافت نشد.',
        statusCode: 401,
      );
    }

    if (user['status'] != 'active') {
      throw AuthException(
        'این حساب کاربری فعال نیست.',
        statusCode: 403,
      );
    }

    return _publicUser(user);
  }
}
