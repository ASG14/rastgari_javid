import 'dart:io';
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
  final displayName = decoded['display_name'];
  final password = decoded['password'];
  final email = decoded['email'];

  if (username is! String ||
      displayName is! String ||
      password is! String ||
      (email != null && email is! String)) {
    return Response.json(
      statusCode: 400,
      body: {
        'error': 'فیلدهای username، display_name و password الزامی هستند.',
      },
    );
  }

  try {
    final user = await _authService.register(
      username: username,
      displayName: displayName,
      password: password,
      email: email as String?,
    );

    return Response.json(
      statusCode: 201,
      body: {
        'message': 'ثبت‌نام با موفقیت انجام شد.',
        'data': user,
      },
    );
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    stderr..writeln('Registration failed: $error')
    ..writeln(stackTrace);

    return Response.json(
      statusCode: 500,
      body: {'error': 'ثبت‌نام با خطا مواجه شد.'},
    );
  }
}
