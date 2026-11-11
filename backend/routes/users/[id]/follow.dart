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

Future<Response> onRequest(
  RequestContext context,
  String id,
) async {
  if (context.request.method.value != 'POST') {
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

  final targetUserId = int.tryParse(id);

  if (targetUserId == null || targetUserId < 1) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'شناسه کاربر مقصد معتبر نیست.'},
    );
  }

  try {
    final currentUser = await _authService.getCurrentUser(parts[1]);
    final actorUserId = int.tryParse(
      currentUser['id']?.toString() ?? '',
    );

    if (actorUserId == null || actorUserId < 1) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
      );
    }

    final result = await _relationshipService.followUser(
      actorUserId: actorUserId,
      targetUserId: targetUserId,
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
      'Follow user request failed',
      error: error,
      stackTrace: stackTrace,
      name: 'users.follow',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'در انجام عملیات دنبال کردن کاربر خطایی رخ داد.'},
    );
  }
}
