
import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/posts/application/post_service.dart';
import 'package:backend/src/features/posts/data/post_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final _authService = AuthService(AuthRepository());
final _postService = PostService(PostRepository());

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
      body: {'error': 'برای ادامه ابتدا وارد حساب کاربری شوید.'},
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
    final userId = int.tryParse(user['id']?.toString() ?? '');

    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
      );
    }

    final queryParameters = context.request.uri.queryParameters;

    final limitValue = queryParameters['limit'];
    final limit = limitValue == null ? 20 : int.tryParse(limitValue);

    if (limit == null || limit < 1 || limit > 50) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'پارامتر limit باید عددی بین ۱ تا ۵۰ باشد.',
        },
      );
    }

    final page = await _postService.getOwnPosts(
      userId: userId,
      limit: limit,
      cursor: queryParameters['cursor'],
    );

    return Response.json(
      body: {
        'message': 'پست‌های کاربر دریافت شدند.',
        ...page,
      },
    );
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } on PostException catch (error) {
    return Response.json(
      statusCode: 400,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to fetch current user posts',
      error: error,
      stackTrace: stackTrace,
      name: 'users.me.posts',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دریافت پست‌های کاربر با خطا مواجه شد.'},
    );
  }
}
