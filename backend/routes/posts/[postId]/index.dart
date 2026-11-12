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
  final parsedPostId = int.tryParse(postId);

  if (parsedPostId == null || parsedPostId < 1) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'شناسه پست معتبر نیست.'},
    );
  }

  switch (context.request.method.value) {
    case 'GET':
      return _getPost(context, parsedPostId);

    case 'PATCH':
      return _updatePost(context, parsedPostId);

    case 'DELETE':
      return _deletePost(context, parsedPostId);

    default:
      return Response.json(
        statusCode: 405,
        body: {'error': 'این متد پشتیبانی نمی‌شود.'},
      );
  }
}

Future<Response> _getPost(
  RequestContext context,
  int postId,
) async {
  try {
    int? currentUserId;

    final authorization = context.request.headers['authorization'];

    if (authorization != null && authorization.isNotEmpty) {
      final userId = await _authenticate(context);

      if (userId == null) {
        return Response.json(
          statusCode: 401,
          body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
        );
      }

      currentUserId = userId;
    }

    final post = await postService.getPostById(
      postId: postId,
      currentUserId: currentUserId,
    );

    if (post == null) {
      return Response.json(
        statusCode: 404,
        body: {'error': 'پست موردنظر پیدا نشد یا قابل مشاهده نیست.'},
      );
    }

    return Response.json(body: {'data': post});
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

Future<Response> _updatePost(
  RequestContext context,
  int postId,
) async {
  try {
    final userId = await _authenticate(context);

    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'برای ویرایش پست ابتدا وارد حساب کاربری شوید.'},
      );
    }

    final decoded = await _readJson(context);

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

    final post = await postService.updatePost(
      postId: postId,
      userId: userId,
      content: content,
    );

    if (post == null) {
      return Response.json(
        statusCode: 404,
        body: {'error': 'پست موردنظر پیدا نشد یا اجازه ویرایش ندارید.'},
      );
    }

    return Response.json(
      body: {
        'message': 'پست با موفقیت ویرایش شد.',
        'data': post,
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
      'Failed to update post.',
      error: error,
      stackTrace: stackTrace,
      name: 'posts.update',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'ویرایش پست با خطا مواجه شد.'},
    );
  }
}

Future<Response> _deletePost(
  RequestContext context,
  int postId,
) async {
  try {
    final userId = await _authenticate(context);

    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'برای حذف پست ابتدا وارد حساب کاربری شوید.'},
      );
    }

    final deleted = await postService.deletePost(
      postId: postId,
      userId: userId,
    );

    if (!deleted) {
      return Response.json(
        statusCode: 404,
        body: {'error': 'پست موردنظر پیدا نشد یا اجازه حذف ندارید.'},
      );
    }

    return Response.json(
      body: {'message': 'پست با موفقیت حذف شد.'},
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
      'Failed to delete post.',
      error: error,
      stackTrace: stackTrace,
      name: 'posts.delete',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'حذف پست با خطا مواجه شد.'},
    );
  }
}

Future<int?> _authenticate(RequestContext context) async {
  final authorization = context.request.headers['authorization'];

  if (authorization == null || authorization.isEmpty) {
    throw AuthException(
      'برای انجام این عملیات ابتدا وارد حساب کاربری شوید.',
      statusCode: 401,
    );
  }

  final parts = authorization.trim().split(RegExp(r'\s+'));

  if (parts.length != 2 ||
      parts[0].toLowerCase() != 'bearer' ||
      parts[1].isEmpty) {
    throw AuthException(
      'فرمت توکن ورود معتبر نیست.',
      statusCode: 401,
    );
  }

  final user = await authService.getCurrentUser(parts[1]);
  final userId = int.tryParse(user['id']?.toString() ?? '');

  if (userId == null || userId < 1) {
    throw AuthException(
      'اطلاعات حساب کاربری معتبر نیست.',
      statusCode: 401,
    );
  }

  return userId;
}

Future<Object?> _readJson(RequestContext context) async {
  try {
    return await context.request.json();
  } catch (_) {
    return null;
  }
}
