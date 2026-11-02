import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/notifications/application/notification_service.dart';
import 'package:backend/src/features/notifications/data/notification_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final authService = AuthService(AuthRepository());
final notificationService = NotificationService(NotificationRepository());

Future<Response> onRequest(RequestContext context) async {
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
      body: {'error': 'برای مشاهده اعلان‌ها باید وارد حساب کاربری شوید.'},
    );
  }

  final parts = authorization.trim().split(RegExp(r'\s+'));

  if (parts.length != 2 ||
      parts[0].toLowerCase() != 'bearer' ||
      parts[1].isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'توکن احراز هویت معتبر نیست.'},
    );
  }

  late final Map<String, dynamic> user;

  try {
    user = await authService.getCurrentUser(parts[1]);
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to authenticate unread notification count request.',
      error: error,
      stackTrace: stackTrace,
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'خطایی در احراز هویت رخ داد.'},
    );
  }

  final userId = int.tryParse(user['id']?.toString() ?? '');

  if (userId == null || userId < 1) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'اطلاعات کاربر معتبر نیست.'},
    );
  }

  try {
    final unreadCount = await notificationService.getUnreadCount(
      userId: userId,
    );

    return Response.json(
      body: {
        'data': {
          'unread_count': unreadCount,
        },
      },
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to retrieve unread notification count.',
      error: error,
      stackTrace: stackTrace,
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دریافت تعداد اعلان‌های خوانده‌نشده ناموفق بود.'},
    );
  }
}
