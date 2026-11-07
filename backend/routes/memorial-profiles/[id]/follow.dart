import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/memorial_profiles/application/memorial_profile_service.dart';
import 'package:backend/src/features/memorial_profiles/data/memorial_profile_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final service = MemorialProfileService(MemorialProfileRepository());
final authService = AuthService(AuthRepository());

Future<Response> onRequest(RequestContext context, String id) async {
  final method = context.request.method.value;

  if (method != 'POST' && method != 'DELETE') {
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

    if (method == 'DELETE') {
      await service.unfollowProfile(
        profileId: profileId,
        userId: userId,
      );

      return Response.json(
        body: {'message': 'دنبال‌کردن پروفایل لغو شد.'},
      );
    }

    final decoded = await _readJson(context);
    if (decoded is! Map<String, dynamic> ||
        decoded['relationship'] is! String) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'نسبت شما با مرحوم الزامی است.'},
      );
    }

    final membership = await service.followProfile(
      profileId: profileId,
      userId: userId,
      relationship: decoded['relationship'] as String,
    );

    return Response.json(
      body: {
        'message': 'پروفایل با موفقیت دنبال شد.',
        'data': membership,
      },
    );
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } on MemorialProfileException catch (error) {
    return Response.json(
      statusCode: 400,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Memorial follow operation failed',
      error: error,
      stackTrace: stackTrace,
      name: 'memorial_profiles.follow',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'عملیات دنبال‌کردن پروفایل با خطا مواجه شد.'},
    );
  }
}

Future<Object?> _readJson(RequestContext context) async {
  try {
    return await context.request.json();
  } catch (_) {
    return null;
  }
}
