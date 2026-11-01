import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/posts/application/post_service.dart';
import 'package:backend/src/features/posts/data/post_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final postService = PostService(PostRepository());
final authService = AuthService(AuthRepository());

Future<Response> onRequest(
  RequestContext context,
  String postId,
) async {
  final method = context.request.method.value;

  if (method != 'POST' && method != 'DELETE') {
    return Response.json(
      statusCode: 405,
      body: {'error': 'این متد پشتیبانی نمی‌شود.'},
    );
  }

  final parsedPostId = int.tryParse(postId);

  if (parsedPostId == null || parsedPostId < 1) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'شناسه پست معتبر نیست.'},
    );
  }

  final authorization = context.request.headers['authorization'];

  if (authorization == null || authorization.isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'برای ثبت همدلی ابتدا وارد حساب کاربری شوید.'},
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
      'Like request authentication failed',
      error: error,
      stackTrace: stackTrace,
      name: 'posts.like',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'بررسی هویت کاربر با خطا مواجه شد.'},
    );
  }

  final userId = int.tryParse(user['id']?.toString() ?? '');

  if (userId == null || userId < 1) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
    );
  }

  try {
    final result = await postService.setPostLike(
      postId: parsedPostId,
      userId: userId,
      isLiked: method == 'POST',
    );

    if (result == null) {
      return Response.json(
        statusCode: 404,
        body: {'error': 'نوشته موردنظر یافت نشد یا قابل همدلی نیست.'},
      );
    }

    return Response.json(
      body: {
        'message': method == 'POST' ? 'همدلی ثبت شد.' : 'همدلی لغو شد.',
        'data': result,
      },
    );
  } on PostException catch (error) {
    return Response.json(
      statusCode: 400,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to update post like',
      error: error,
      stackTrace: stackTrace,
      name: 'posts.like',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'به‌روزرسانی همدلی با خطا مواجه شد.'},
    );
  }
}
