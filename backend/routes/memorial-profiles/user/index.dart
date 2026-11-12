import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/memorial_profiles/application/memorial_profile_service.dart';
import 'package:backend/src/features/memorial_profiles/data/memorial_profile_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final service = MemorialProfileService(MemorialProfileRepository());
final authService = AuthService(AuthRepository());

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method.value != 'GET') {
    return Response.json(
      statusCode: 405,
      body: {'error': 'این متد پشتیبانی نمی‌شود.'},
    );
  }

  final authorization = context.request.headers['authorization'];
  if (authorization == null || authorization.isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'ابتدا وارد حساب کاربری شوید.'},
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

  try {
    final user = await authService.getCurrentUser(parts[1]);
    final userId = int.tryParse(user['id']?.toString() ?? '');

    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
      );
    }

    final profiles = await service.getUserProfiles(userId: userId);

    return Response.json(
      body: {'data': profiles},
    );
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to retrieve user memorial profiles',
      error: error,
      stackTrace: stackTrace,
      name: 'memorial_profiles.user',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دریافت پروفایل‌های کاربر با خطا مواجه شد.'},
    );
  }
}
