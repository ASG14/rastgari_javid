import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final _authService = AuthService(AuthRepository());

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method.value != 'GET') {
    return Response.json(
      statusCode: 405,
      body: {'error': 'این متد پشتیبانی نمی‌شود.'},
    );
  }

  final authorization = context.request.headers['authorization'];

  if (authorization == null) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'توکن ورود ارسال نشده است.'},
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
    final user = await _authService.getCurrentUser(parts[1]);

    return Response.json(
      body: {
        'message': 'اطلاعات کاربر دریافت شد.',
        'data': user,
      },
    );
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Getting current user failed',
      error: error,
      stackTrace: stackTrace,
      name: 'auth.me',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دریافت اطلاعات کاربر با خطا مواجه شد.'},
    );
  }
}