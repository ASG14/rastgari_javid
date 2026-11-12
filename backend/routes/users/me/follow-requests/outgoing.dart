import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/users/application/follow_request_query_service.dart';
import 'package:backend/src/features/users/data/follow_request_query_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final _authService = AuthService(AuthRepository());

final _queryService = FollowRequestQueryService(
  FollowRequestQueryRepository(),
);

/// Handles GET requests for outgoing follow requests.
Future<Response> onRequest(RequestContext context) async {
  if (context.request.method.value != 'GET') {
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

  final queryParameters = context.request.uri.queryParameters;
  final limit = int.tryParse(queryParameters['limit'] ?? '20');
  final offset = int.tryParse(queryParameters['offset'] ?? '0');

  if (limit == null || offset == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'پارامترهای صفحه‌بندی معتبر نیستند.'},
    );
  }

  try {
    final currentUser = await _authService.getCurrentUser(parts[1]);

    final userId = int.tryParse(
      currentUser['id']?.toString() ?? '',
    );

    if (userId == null || userId < 1) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
      );
    }

    final result = await _queryService.getRequests(
      userId: userId,
      incoming: false,
      limit: limit,
      offset: offset,
    );

    return Response.json(
      body: {
        'message': 'فهرست درخواست‌های خروجی دریافت شد.',
        'data': result,
      },
    );
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } on FollowRequestQueryException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Get outgoing follow requests failed.',
      error: error,
      stackTrace: stackTrace,
      name: 'users.follow_requests.outgoing',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'دریافت درخواست‌های خروجی با خطا مواجه شد.'},
    );
  }
}
