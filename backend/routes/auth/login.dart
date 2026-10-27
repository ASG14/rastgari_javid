import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final _authService = AuthService(AuthRepository());

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method.value != 'POST') {
    return Response.json(
      statusCode: 405,
      body: {'error': 'این متد پشتیبانی نمی‌شود.'},
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

  final username = decoded['username'];
  final password = decoded['password'];

  if (username is! String ||
      username.trim().isEmpty ||
      password is! String ||
      password.isEmpty) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'نام کاربری و رمز عبور الزامی هستند.'},
    );
  }

  try {
    final result = await _authService.login(
      username: username,
      password: password,
    );

    return Response.json(
      body: {
        'message': 'ورود با موفقیت انجام شد.',
        'data': result,
      },
    );
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Login failed',
      error: error,
      stackTrace: stackTrace,
      name: 'auth.login',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'ورود با خطا مواجه شد.'},
    );
  }
}
