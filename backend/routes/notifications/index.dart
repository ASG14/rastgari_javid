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
      'Failed to authenticate notification request.',
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

  final limitParameter = context.request.uri.queryParameters['limit'];
  var limit = 50;

  if (limitParameter != null) {
    final parsedLimit = int.tryParse(limitParameter);

    if (parsedLimit == null || parsedLimit < 1 || parsedLimit > 100) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'پارامتر limit باید عددی بین ۱ تا ۱۰۰ باشد.'},
      );
    }

    limit = parsedLimit;
  }

  try {
    final notifications = await notificationService.getNotifications(
      userId: userId,
      limit: limit,
    );

    return Response.json(
      body: {
        'data': notifications,
        'meta': {
          'limit': limit,
          'count': notifications.length,
        },
      },
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to retrieve notifications.',
      error: error,
      stackTrace: stackTrace,
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دریافت اعلان‌ها با خطا مواجه شد.'},
    );
  }
}
