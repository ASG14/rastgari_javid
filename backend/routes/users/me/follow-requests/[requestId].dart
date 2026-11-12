import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/users/application/user_relationship_service.dart';
import 'package:backend/src/features/users/data/user_relationship_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final _authService = AuthService(AuthRepository());

final _relationshipService = UserRelationshipService(
  UserRelationshipRepository(),
);

/// Handles DELETE requests for cancelling outgoing follow requests.
Future<Response> onRequest(
  RequestContext context,
  String requestId,
) async {
  if (context.request.method.value != 'DELETE') {
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

  final parts = authorization.trim().split(RegExp(r'\s+'));

  if (parts.length != 2 ||
      parts[0].toLowerCase() != 'bearer' ||
      parts[1].isEmpty) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'فرمت توکن ورود معتبر نیست.'},
    );
  }

  final parsedRequestId = int.tryParse(requestId);

  if (parsedRequestId == null || parsedRequestId < 1) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'شناسه درخواست معتبر نیست.'},
    );
  }

  try {
    final currentUser = await _authService.getCurrentUser(parts[1]);

    final requesterUserId = int.tryParse(
      currentUser['id']?.toString() ?? '',
    );

    if (requesterUserId == null || requesterUserId < 1) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
      );
    }

    final result = await _relationshipService.cancelFollowRequest(
      requesterUserId: requesterUserId,
      requestId: parsedRequestId,
    );

    return Response.json(body: result);
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } on UserRelationshipException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Cancel follow request failed.',
      error: error,
      stackTrace: stackTrace,
      name: 'users.follow_requests.cancel',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'لغو درخواست دنبال کردن با خطا مواجه شد.'},
    );
  }
}
