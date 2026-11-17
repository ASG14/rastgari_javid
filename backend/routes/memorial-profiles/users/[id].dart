import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/memorial_profiles/application/memorial_profile_service.dart';
import 'package:backend/src/features/memorial_profiles/data/memorial_profile_repository.dart';
import 'package:backend/src/features/users/application/user_public_profile_service.dart';
import 'package:backend/src/features/users/data/user_public_profile_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final _authService = AuthService(AuthRepository());

final _memorialProfileService = MemorialProfileService(
  MemorialProfileRepository(),
);

final _publicProfileService = UserPublicProfileService(
  UserPublicProfileRepository(),
);

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

  final targetUserId = int.tryParse(id);

  if (targetUserId == null || targetUserId < 1) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'شناسه کاربر مقصد معتبر نیست.'},
    );
  }

  final authorization = context.request.headers['authorization'];

  if (authorization == null || authorization.isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'برای مشاهده اطلاعات ابتدا وارد حساب شوید.'},
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

    // Apply the same privacy and block rules as the public profile.
    final publicProfile = await _publicProfileService.getPublicProfile(
      viewerUserId: viewerUserId,
      targetUserId: targetUserId,
    );

    final profile = publicProfile['profile'];

    if (profile is! Map || profile['can_view_posts'] != true) {
      return Response.json(
        statusCode: 403,
        body: {
          'error':
              'برای مشاهده محتوای این حساب باید دنبال‌کننده پذیرفته‌شده باشید.',
        },
      );
    }

    final memorialProfiles = await _memorialProfileService.getUserProfiles(
      userId: targetUserId,
    );

    return Response.json(
      body: {
        'data': memorialProfiles,
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
      'Failed to retrieve user memorial profiles',
      error: error,
      stackTrace: stackTrace,
      name: 'memorial_profiles.public_user',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دریافت عزیزان آسمانی کاربر با خطا مواجه شد.'},
    );
  }
}
