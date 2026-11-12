import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/comments/application/comment_service.dart';
import 'package:backend/src/features/comments/data/comment_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final commentService = CommentService(CommentRepository());
final authService = AuthService(AuthRepository());

/// Handles update and delete requests for a specific comment.
Future<Response> onRequest(
  RequestContext context,
  String postId,
  String commentId,
) async {
  final parsedPostId = int.tryParse(postId);
  final parsedCommentId = int.tryParse(commentId);

  if (parsedPostId == null ||
      parsedPostId < 1 ||
      parsedCommentId == null ||
      parsedCommentId < 1) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'شناسه پست یا دیدگاه معتبر نیست.'},
    );
  }

  switch (context.request.method.value) {
    case 'PATCH':
      return _updateComment(
        context,
        parsedPostId,
        parsedCommentId,
      );

    case 'DELETE':
      return _deleteComment(
        context,
        parsedPostId,
        parsedCommentId,
      );

    default:
      return Response.json(
        statusCode: 405,
        body: {'error': 'این متد پشتیبانی نمی‌شود.'},
      );
  }
}

Future<Response> _updateComment(
  RequestContext context,
  int postId,
  int commentId,
) async {
  try {
    final userId = await _authenticate(context);
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
        body: {'error': 'متن دیدگاه الزامی است.'},
      );
    }

    final comment = await commentService.updateComment(
      postId: postId,
      commentId: commentId,
      userId: userId,
      content: content,
    );

    if (comment == null) {
      return Response.json(
        statusCode: 404,
        body: {
          'error': 'دیدگاه پیدا نشد یا اجازه ویرایش آن را ندارید.',
        },
      );
    }

    return Response.json(
      body: {
        'message': 'دیدگاه با موفقیت ویرایش شد.',
        'data': comment,
      },
    );
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
      'Failed to update comment.',
      error: error,
      stackTrace: stackTrace,
      name: 'comments.update',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'ویرایش دیدگاه با خطا مواجه شد.'},
    );
  }
}

Future<Response> _deleteComment(
  RequestContext context,
  int postId,
  int commentId,
) async {
  try {
    final userId = await _authenticate(context);

    final deleted = await commentService.deleteComment(
      postId: postId,
      commentId: commentId,
      userId: userId,
    );

    if (!deleted) {
      return Response.json(
        statusCode: 404,
        body: {
          'error': 'دیدگاه پیدا نشد یا اجازه حذف آن را ندارید.',
        },
      );
    }

    return Response.json(
      body: {'message': 'دیدگاه با موفقیت حذف شد.'},
    );
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
      'Failed to delete comment.',
      error: error,
      stackTrace: stackTrace,
      name: 'comments.delete',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'حذف دیدگاه با خطا مواجه شد.'},
    );
  }
}

Future<int> _authenticate(RequestContext context) async {
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
