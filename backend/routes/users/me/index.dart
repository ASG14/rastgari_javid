import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/users/application/user_service.dart';
import 'package:backend/src/features/users/data/user_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final _authService = AuthService(AuthRepository());
final _userService = UserService(UserRepository());

Future<Response> onRequest(RequestContext context) async {
  final method = context.request.method.value;

  if (method != 'GET' && method != 'PATCH') {
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

  try {
    final currentUser = await _authService.getCurrentUser(parts[1]);
    final userId = int.tryParse(currentUser['id']?.toString() ?? '');

    if (userId == null) {
      return Response.json(
        statusCode: 401,
        body: {'error': 'اطلاعات حساب کاربری معتبر نیست.'},
      );
    }

    if (method == 'GET') {
      return Response.json(
        body: {
          'message': 'اطلاعات پروفایل دریافت شد.',
          'data': currentUser,
        },
      );
    }

    final Object? decoded;

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
        body: {'error': 'ساختار درخواست معتبر نیست.'},
      );
    }

    final username = decoded['username'];
    final displayName = decoded['display_name'];
    final updateBio = decoded.containsKey('bio');
    final bio = decoded['bio'];

    if (username != null && username is! String) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'نام کاربری باید متن باشد.'},
      );
    }

    if (displayName != null && displayName is! String) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'نام نمایشی باید متن باشد.'},
      );
    }

    if (updateBio && bio != null && bio is! String) {
      return Response.json(
        statusCode: 400,
        body: {'error': 'توضیحات پروفایل باید متن یا null باشد.'},
      );
    }

    if (username == null && displayName == null && !updateBio) {
      return Response.json(
        statusCode: 400,
        body: {
          'error': 'حداقل یک فیلد برای به‌روزرسانی ارسال کنید.',
        },
      );
    }

    final updatedProfile = await _userService.updateProfile(
      userId: userId,
      username: username as String?,
      displayName: displayName as String?,
      updateBio: updateBio,
      bio: bio as String?,
    );

    return Response.json(
      body: {
        'message': 'پروفایل با موفقیت به‌روزرسانی شد.',
        'data': updatedProfile,
      },
    );
  } on AuthException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } on UserException catch (error) {
    return Response.json(
      statusCode: error.statusCode,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'User profile request failed',
      error: error,
      stackTrace: stackTrace,
      name: 'users.me',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'در پردازش اطلاعات پروفایل خطایی رخ داد.'},
    );
  }
}
