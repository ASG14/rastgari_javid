import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/memorial_profiles/application/memorial_profile_service.dart';
import 'package:backend/src/features/memorial_profiles/data/memorial_profile_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final service = MemorialProfileService(
  MemorialProfileRepository(),
);

final authService = AuthService(
  AuthRepository(),
);

Future<Response> onRequest(
  RequestContext context,
  String id,
) async {
  if (context.request.method.value != 'GET') {
    return Response.json(
      statusCode: 405,
      body: {'error': 'این متد پشتیبانی نمی‌شود.'},
    );
  }

  final profileId = int.tryParse(id);

  if (profileId == null || profileId < 1) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'شناسه پروفایل معتبر نیست.'},
    );
  }

  final authorization = context.request.headers['authorization'];

  if (authorization == null || authorization.isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'برای مشاهده پروفایل ابتدا وارد حساب کاربری شوید.'},
    );
  }

  final parts = authorization.split(RegExp(r'\s+'));

  if (parts.length != 2 ||
      parts[0].toLowerCase() != 'bearer' ||
      parts[1].isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'فرمت توکن ورود معتبر نیست.'},
    );
  }

  late final int userId;

  try {
    final user = await authService.getCurrentUser(parts[1]);
    final parsedId = int.tryParse(user['id']?.toString() ?? '');

    if (parsedId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
      );
    }

    userId = parsedId;
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Memorial profile authentication failed',
      error: error,
      stackTrace: stackTrace,
      name: 'memorial_profiles.detail',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'بررسی هویت کاربر با خطا مواجه شد.'},
    );
  }

  try {
    final profile = await service.getProfileById(
      profileId: profileId,
      userId: userId,
    );

    if (profile == null) {
      return Response.json(
        statusCode: 404,
        body: {'error': 'پروفایل موردنظر پیدا نشد.'},
      );
    }

    return Response.json(
      body: {
        'data': profile,
      },
    );
  } on MemorialProfileException catch (error) {
    return Response.json(
      statusCode: 400,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to retrieve memorial profile',
      error: error,
      stackTrace: stackTrace,
      name: 'memorial_profiles.detail',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دریافت اطلاعات پروفایل با خطا مواجه شد.'},
    );
  }
}