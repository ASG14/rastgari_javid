import 'dart:developer' as developer;

import 'package:backend/src/features/posts/application/post_service.dart';
import 'package:backend/src/features/posts/data/post_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final postService = PostService(PostRepository());

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method.value;

  if (method == 'GET') {
    try {
      final posts = await postService.getPublicPosts();

      return Response.json(
        body: {
          'data': posts,
        },
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to fetch posts',
        error: error,
        stackTrace: stackTrace,
        name: 'posts',
      );

      return Response.json(
        statusCode: 500,
        body: {
          'error': 'دریافت پست‌ها با خطا مواجه شد.',
        },
      );
    }
  }

  if (method == 'POST') {
    try {
      final body = await context.request.json();

      if (body is! Map<String, dynamic>) {
        return Response.json(
          statusCode: 400,
          body: {
            'error': 'ساختار درخواست نامعتبر است.',
          },
        );
      }

      final content = body['content'];

      if (content is! String || content.trim().isEmpty) {
        return Response.json(
          statusCode: 400,
          body: {
            'error': 'متن پست الزامی است.',
          },
        );
      }

      final newPost = {
        'id': 3,
        'author': 'کاربر آزمایشی',
        'content': content.trim(),
        'likes_count': 0,
      };

      return Response.json(
        statusCode: 201,
        body: {
          'message': 'پست با موفقیت دریافت شد.',
          'data': newPost,
        },
      );
    } catch (_) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'بدنه درخواست باید JSON معتبر باشد.',
        },
      );
    }
  }

  return Response.json(
    statusCode: 405,
    body: {
      'error': 'این متد پشتیبانی نمی‌شود.',
    },
  );
}
