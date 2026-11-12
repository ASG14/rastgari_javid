import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/comments/application/comment_service.dart';
import 'package:backend/src/features/comments/data/comment_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final commentService = CommentService(CommentRepository());
final authService = AuthService(AuthRepository());

/// Handles GET and POST requests for a post's comments.
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

  final method = context.request.method.value;

  if (method == 'GET') {
    return _getComments(context, parsedPostId);
  }

  if (method == 'POST') {
    return _createComment(context, parsedPostId);
  }

  return Response.json(
    statusCode: 405,
    body: {'error': 'این متد پشتیبانی نمی‌شود.'},
  );
}

Future<Response> _getComments(
  RequestContext context,
  int postId,
) async {
  try {
    int? viewerUserId;
    final authorization = context.request.headers['authorization'];

    if (authorization != null && authorization.isNotEmpty) {
      final parts = authorization.split(RegExp(r'\s+'));

      if (parts.length != 2 ||
          parts[0].toLowerCase() != 'bearer' ||
          parts[1].isEmpty) {
        return Response.json(
          statusCode: 401,
          body: {'error': 'فرمت توکن ورود معتبر نیست.'},
        );
      }

      final user = await authService.getCurrentUser(parts[1]);
      viewerUserId = int.tryParse(user['id']?.toString() ?? '');

      if (viewerUserId == null || viewerUserId < 1) {
        return Response.json(
          statusCode: 401,
          body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
        );
      }
    }

    final comments = await commentService.getPostComments(
      postId: postId,
      viewerUserId: viewerUserId,
    );

    if (comments == null) {
      return Response.json(
        statusCode: 404,
        body: {'error': 'پست موردنظر یافت نشد یا دسترسی به آن مجاز نیست.'},
      );
    }

    return Response.json(body: {'data': comments});
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } on CommentException catch (error) {
    return Response.json(
      statusCode: 400,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to fetch post comments',
      error: error,
      stackTrace: stackTrace,
      name: 'comments.get',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دریافت دیدگاه‌ها با خطا مواجه شد.'},
    );
  }
}

Future<Response> _createComment(
  RequestContext context,
  int postId,
) async {
  final authorization = context.request.headers['authorization'];

  if (authorization == null || authorization.isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'برای ثبت دیدگاه ابتدا وارد حساب کاربری شوید.'},
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
      'Comment authentication failed',
      error: error,
      stackTrace: stackTrace,
      name: 'comments.auth',
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
      body: {'error': 'متن دیدگاه الزامی است.'},
    );
  }

  final rawParentCommentId = decoded['parent_comment_id'];
  int? parentCommentId;

  if (rawParentCommentId != null) {
    if (rawParentCommentId is int) {
      parentCommentId = rawParentCommentId;
    } else if (rawParentCommentId is String) {
      parentCommentId = int.tryParse(rawParentCommentId);
    }

    if (parentCommentId == null || parentCommentId < 1) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'شناسه دیدگاه والد معتبر نیست.'},
      );
    }
  }

  final userId = int.tryParse(user['id']?.toString() ?? '');

  if (userId == null || userId < 1) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
    );
  }

  try {
    final comment = await commentService.createComment(
      postId: postId,
      userId: userId,
      content: content,
      parentCommentId: parentCommentId,
    );

    if (comment == null) {
      return Response.json(
        statusCode: 404,
        body: {
          'error':
              'پست، حساب کاربری یا دیدگاه والد معتبر نیست، '
              'یا دسترسی مجاز نیست.',
        },
      );
    }

    return Response.json(
      statusCode: 201,
      body: {
        'message': 'دیدگاه با موفقیت ثبت شد.',
        'data': comment,
      },
    );
  } on CommentException catch (error) {
    return Response.json(
      statusCode: 400,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to create comment',
      error: error,
      stackTrace: stackTrace,
      name: 'comments.create',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'ثبت دیدگاه با خطا مواجه شد.'},
    );
  }
}
