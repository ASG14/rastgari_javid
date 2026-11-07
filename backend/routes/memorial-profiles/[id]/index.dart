import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/memorial_profiles/application/memorial_profile_service.dart';
import 'package:backend/src/features/memorial_profiles/data/memorial_profile_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final service = MemorialProfileService(MemorialProfileRepository());
final authService = AuthService(AuthRepository());

Future<Response> onRequest(
  RequestContext context,
  String id,
) async {
  final profileId = int.tryParse(id);

  if (profileId == null || profileId < 1) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'شناسه پروفایل معتبر نیست.'},
    );
  }

  final userId = await _authenticate(context);
  if (userId == null) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'ابتدا وارد حساب کاربری شوید.'},
    );
  }

  try {
    switch (context.request.method.value) {
      case 'GET':
        final profile = await service.getProfileById(
          profileId: profileId,
          userId: userId,
        );

        if (profile == null) {
          return Response.json(
            statusCode: 404,
            body: {'error': 'پروفایل موردنظر پیدا نشد.'},
          );
        }

        return Response.json(body: {'data': profile});

      case 'PUT':
        final decoded = await _readJson(context);
        if (decoded is! Map<String, dynamic>) {
          return Response.json(
            statusCode: 400,
            body: {'error': 'ساختار درخواست نامعتبر است.'},
          );
        }

        final fullName = decoded['full_name'];
        final birthDate = decoded['birth_date'];
        final deathDate = decoded['death_date'];
        final memorialText = decoded['memorial_text'];
        final graveAddress = decoded['grave_address'];
        final photoId = decoded['photo_media_asset_id'];

        if (fullName is! String ||
            (birthDate != null && birthDate is! String) ||
            (deathDate != null && deathDate is! String) ||
            (memorialText != null && memorialText is! String) ||
            (graveAddress != null && graveAddress is! String) ||
            (photoId != null && photoId is! int)) {
          return Response.json(
            statusCode: 400,
            body: {'error': 'نوع یکی از فیلدهای ارسالی معتبر نیست.'},
          );
        }

        final profile = await service.updateProfile(
          profileId: profileId,
          userId: userId,
          fullName: fullName,
          birthDate: birthDate as String?,
          deathDate: deathDate as String?,
          memorialText: memorialText as String?,
          graveAddress: graveAddress as String?,
          photoMediaAssetId: photoId as int?,
        );

        return Response.json(
          body: {
            'message': 'پروفایل با موفقیت ویرایش شد.',
            'data': profile,
          },
        );

      case 'DELETE':
        await service.deleteProfile(
          profileId: profileId,
          userId: userId,
        );

        return Response.json(
          body: {'message': 'پروفایل با موفقیت حذف شد.'},
        );

      default:
        return Response.json(
          statusCode: 405,
          body: {'error': 'این متد پشتیبانی نمی‌شود.'},
        );
    }
  } on MemorialProfileException catch (error) {
    return Response.json(
      statusCode: 400,
      body: {'error': error.message},
    );
  } on MemorialProfileRepositoryException catch (error) {
    return Response.json(
      statusCode: 400,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Memorial profile request failed',
      error: error,
      stackTrace: stackTrace,
      name: 'memorial_profiles.detail',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'عملیات روی پروفایل با خطا مواجه شد.'},
    );
  }
}

Future<int?> _authenticate(RequestContext context) async {
  final authorization = context.request.headers['authorization'];
  if (authorization == null || authorization.isEmpty) return null;

  final parts = authorization.split(RegExp(r'\s+'));
  if (parts.length != 2 ||
      parts[0].toLowerCase() != 'bearer' ||
      parts[1].isEmpty) {
    return null;
  }

  try {
    final user = await authService.getCurrentUser(parts[1]);
    return int.tryParse(user['id']?.toString() ?? '');
  } on AuthException {
    return null;
  }
}

Future<Object?> _readJson(RequestContext context) async {
  try {
    return await context.request.json();
  } catch (_) {
    return null;
  }
}
