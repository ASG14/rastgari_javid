import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/users/application/user_public_profile_service.dart';
import 'package:backend/src/features/users/data/user_public_profile_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final _authService = AuthService(AuthRepository());

final _profileService = UserPublicProfileService(
  UserPublicProfileRepository(),
);

/// Handles GET requests for public user profiles.
Future<Response> onRequest(
  RequestContext context,
  String id,
) async {
  if (context.request.method != HttpMethod.get) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'این متد پشتیبانی نمی‌شود.'},
    );
  }

  final authorization = context.request.headers['authorization'];

  if (authorization == null || authorization.isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'برای مشاهده پروفایل ابتدا وارد حساب کاربری شوید.'},
    );
  }

  final parts = authorization.trim().split(RegExp(r'\s+'));

  if (parts.length != 2 ||
      parts[0].toLowerCase() != 'bearer' ||
      parts[1].isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'فرمت توکن ورود معتبر نیست.'},
    );
  }

  final targetUserId = int.tryParse(id);

  if (targetUserId == null || targetUserId < 1) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'شناسه کاربر مقصد معتبر نیست.'},
    );
  }

  try {
    final currentUser = await _authService.getCurrentUser(parts[1]);

    final viewerUserId = int.tryParse(
      currentUser['id']?.toString() ?? '',
    );

    if (viewerUserId == null || viewerUserId < 1) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
      );
    }

    final profile = await _profileService.getPublicProfile(
      viewerUserId: viewerUserId,
      targetUserId: targetUserId,
    );

    return Response.json(
      body: {
        'message': 'پروفایل کاربر دریافت شد.',
        'data': profile,
      },
    );
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } on UserPublicProfileException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to retrieve public user profile.',
      error: error,
      stackTrace: stackTrace,
      name: 'users.public_profile',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دریافت پروفایل کاربر با خطا مواجه شد.'},
    );
  }
}
