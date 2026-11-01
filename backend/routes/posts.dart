import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/posts/application/post_service.dart';
import 'package:backend/src/features/posts/data/post_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final postService = PostService(PostRepository());
final authService = AuthService(AuthRepository());

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method.value;

  if (method == 'GET') {
    try {
      final posts = await postService.getPublicPosts();

      return Response.json(
        body: {'data': posts},
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
        body: {'error': 'دریافت پست‌ها با خطا مواجه شد.'},
      );
    }
  }

  if (method == 'POST') {
    return _createPost(context);
  }

  return Response.json(
    statusCode: 405,
    body: {'error': 'این متد پشتیبانی نمی‌شود.'},
  );
}

Future<Response> _createPost(RequestContext context) async {
  final authorization = context.request.headers['authorization'];

  if (authorization == null) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'برای انتشار پست ابتدا وارد حساب کاربری شوید.'},
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
      'Post author authentication failed',
      error: error,
      stackTrace: stackTrace,
      name: 'posts.create',
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

  if (decoded is! Map<String, dynamic>) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'ساختار درخواست نامعتبر است.'},
    );
  }

  final content = decoded['content'];

  if (content is! String) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'متن پست الزامی است.'},
    );
  }

  final userId = int.tryParse(user['id']?.toString() ?? '');

  if (userId == null) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
    );
  }

  try {
    final newPost = await postService.createPublicPost(
      userId: userId,
      content: content,
    );

    return Response.json(
      statusCode: 201,
      body: {
        'message': 'پست با موفقیت منتشر شد.',
        'data': newPost,
      },
    );
  } on PostException catch (error) {
    return Response.json(
      statusCode: 400,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to create post',
      error: error,
      stackTrace: stackTrace,
      name: 'posts.create',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'انتشار پست با خطا مواجه شد.'},
    );
  }
}
