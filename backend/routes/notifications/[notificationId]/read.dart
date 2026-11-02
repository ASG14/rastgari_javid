import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/notifications/application/notification_service.dart';
import 'package:backend/src/features/notifications/data/notification_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final authService = AuthService(AuthRepository());
final notificationService = NotificationService(NotificationRepository());

Future<Response> onRequest(
  RequestContext context,
  String notificationId,
) async {
  if (context.request.method != HttpMethod.patch) {
    return Response.json(
      statusCode: 405,
      body: {'error': 'این متد پشتیبانی نمی‌شود.'},
    );
  }

  final parsedNotificationId = int.tryParse(notificationId);

  if (parsedNotificationId == null || parsedNotificationId < 1) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'شناسه اعلان معتبر نیست.'},
    );
  }

  final authorization = context.request.headers['authorization'];

  if (authorization == null || authorization.isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'برای تغییر وضعیت اعلان باید وارد حساب کاربری شوید.'},
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
      'Failed to authenticate mark-notification-as-read request.',
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
    final markedAsRead = await notificationService.markAsRead(
      notificationId: parsedNotificationId,
      userId: userId,
    );

    if (!markedAsRead) {
      return Response.json(
        statusCode: 404,
        body: {'error': 'اعلان موردنظر پیدا نشد.'},
      );
    }

    return Response.json(
      body: {
        'message': 'اعلان به‌عنوان خوانده‌شده علامت‌گذاری شد.',
        'data': {
          'id': parsedNotificationId,
          'is_read': true,
        },
      },
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to mark notification as read.',
      error: error,
      stackTrace: stackTrace,
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'تغییر وضعیت اعلان با خطا مواجه شد.'},
    );
  }
}
