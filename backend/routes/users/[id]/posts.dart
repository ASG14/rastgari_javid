import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/posts/application/post_service.dart';
import 'package:backend/src/features/posts/data/post_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final _authService = AuthService(AuthRepository());
final _postService = PostService(PostRepository());

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
      body: {
        'error': 'برای مشاهده نوشته‌ها ابتدا وارد حساب کاربری شوید.',
      },
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
    final user = await _authService.getCurrentUser(parts[1]);

    final currentUserId = int.tryParse(
      user['id']?.toString() ?? '',
    );

    if (currentUserId == null || currentUserId < 1) {
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

    final page = await _postService.getUserPosts(
      targetUserId: targetUserId,
      currentUserId: currentUserId,
      limit: limit,
      cursor: queryParameters['cursor'],
    );

    return Response.json(
      body: {
        'message': 'نوشته‌های کاربر دریافت شدند.',
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
      'Failed to fetch user profile posts',
      error: error,
      stackTrace: stackTrace,
      name: 'users.profile.posts',
    );

    return Response.json(
      statusCode: 500,
      body: {
        'error': 'دریافت نوشته‌های کاربر با خطا مواجه شد.',
      },
    );
  }
}
