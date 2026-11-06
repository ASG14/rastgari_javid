
import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/memorial_profiles/application/memorial_profile_service.dart';
import 'package:backend/src/features/memorial_profiles/data/memorial_profile_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final service = MemorialProfileService(MemorialProfileRepository());
final authService = AuthService(AuthRepository());

Future<Response> onRequest(RequestContext context, String id) async {
  if (context.request.method.value != 'POST') {
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

  if (authorization == null) {
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
      'Memorial follow authentication failed',
      error: error,
      stackTrace: stackTrace,
      name: 'memorial_profiles.follow',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'بررسی هویت کاربر با خطا مواجه شد.'},
    );
  }

  late final Object? decoded;

  try {
    decoded = await context.request.json();
  } catch (_) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'بدنه درخواست باید JSON معتبر باشد.'},
    );
  }

  if (decoded is! Map<String, dynamic> ||
      decoded['relationship'] is! String) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'نسبت شما با مرحوم الزامی است.'},
    );
  }

  try {
    final membership = await service.followProfile(
      profileId: profileId,
      userId: userId,
      relationship: decoded['relationship'] as String,
    );

    return Response.json(
      statusCode: 200,
      body: {
        'message': 'پروفایل با موفقیت دنبال شد.',
        'data': membership,
      },
    );
  } on MemorialProfileException catch (error) {
    return Response.json(
      statusCode: 400,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to follow memorial profile',
      error: error,
      stackTrace: stackTrace,
      name: 'memorial_profiles.follow',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دنبال‌کردن پروفایل با خطا مواجه شد.'},
    );
  }
}
