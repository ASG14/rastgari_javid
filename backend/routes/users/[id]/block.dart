
import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/users/application/user_block_service.dart';
import 'package:backend/src/features/users/data/user_block_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final _authService = AuthService(AuthRepository());
final _blockService = UserBlockService(UserBlockRepository());

Future<Response> onRequest(
  RequestContext context,
  String id,
) async {
  final method = context.request.method.value;

  if (method != 'POST' && method != 'DELETE') {
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

    final result = method == 'POST'
        ? await _blockService.blockUser(
            blockerUserId: actorUserId,
            blockedUserId: targetUserId,
          )
        : await _blockService.unblockUser(
            blockerUserId: actorUserId,
            blockedUserId: targetUserId,
          );

    return Response.json(body: result);
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } on UserBlockException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'User block operation failed',
      error: error,
      stackTrace: stackTrace,
      name: 'users.block',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'در انجام عملیات مسدودسازی کاربر خطایی رخ داد.'},
    );
  }
}
