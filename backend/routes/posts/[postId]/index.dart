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
  if (context.request.method != HttpMethod.get) {
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

  try {
    int? currentUserId;

    final authorization = context.request.headers['authorization'];

    if (authorization != null && authorization.isNotEmpty) {
      final parts = authorization.trim().split(RegExp(r'\s+'));

      if (parts.length != 2 ||
          parts[0].toLowerCase() != 'bearer' ||
          parts[1].isEmpty) {
        return Response.json(
          statusCode: 401,
          body: {'error': 'فرمت توکن ورود معتبر نیست.'},
        );
      }

      final user = await authService.getCurrentUser(parts[1]);
      currentUserId = int.tryParse(user['id']?.toString() ?? '');

      if (currentUserId == null || currentUserId < 1) {
        return Response.json(
          statusCode: 401,
          body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
        );
      }
    }

    final post = await postService.getPostById(
      postId: parsedPostId,
      currentUserId: currentUserId,
    );

    if (post == null) {
      return Response.json(
        statusCode: 404,
        body: {'error': 'پست موردنظر پیدا نشد یا قابل مشاهده نیست.'},
      );
    }

    return Response.json(
      body: {'data': post},
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
      'Failed to retrieve post details.',
      error: error,
      stackTrace: stackTrace,
      name: 'posts.detail',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دریافت اطلاعات پست با خطا مواجه شد.'},
    );
  }
}
