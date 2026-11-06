
import 'dart:developer' as developer;

import 'package:backend/src/features/auth/application/auth_service.dart';
import 'package:backend/src/features/auth/data/auth_repository.dart';
import 'package:backend/src/features/memorial_profiles/application/memorial_profile_service.dart';
import 'package:backend/src/features/memorial_profiles/data/memorial_profile_repository.dart';
import 'package:dart_frog/dart_frog.dart';

final memorialProfileService = MemorialProfileService(
  MemorialProfileRepository(),
);

final authService = AuthService(AuthRepository());

Future<Response> onRequest(RequestContext context) async {
  final userId = await _authenticate(context);

  if (userId == null) {
    return Response.json(
      statusCode: 401,
      body: {'error': 'برای استفاده از این بخش ابتدا وارد حساب کاربری شوید.'},
    );
  }

  final method = context.request.method.value;

  if (method == 'POST') {
    return _createProfile(context, userId);
  }

  if (method == 'GET') {
    return _searchProfiles(context);
  }

  return Response.json(
    statusCode: 405,
    body: {'error': 'این متد پشتیبانی نمی‌شود.'},
  );
}

Future<int?> _authenticate(RequestContext context) async {
  final authorization = context.request.headers['authorization'];

  if (authorization == null || authorization.isEmpty) {
    return null;
  }

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
  } catch (error, stackTrace) {
    developer.log(
      'Memorial profile authentication failed',
      error: error,
      stackTrace: stackTrace,
      name: 'memorial_profiles.auth',
    );
    rethrow;
  }
}

Future<Response> _createProfile(
  RequestContext context,
  int userId,
) async {
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

  final fullName = decoded['full_name'];
  final relationship = decoded['relationship'];
  final birthDate = decoded['birth_date'];
  final deathDate = decoded['death_date'];
  final memorialText = decoded['memorial_text'];
  final graveAddress = decoded['grave_address'];
  final photoMediaAssetId = decoded['photo_media_asset_id'];

  if (fullName is! String || relationship is! String) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'نام مرحوم و نسبت شما با ایشان الزامی است.'},
    );
  }

  if (birthDate != null && birthDate is! String ||
      deathDate != null && deathDate is! String ||
      memorialText != null && memorialText is! String ||
      graveAddress != null && graveAddress is! String ||
      photoMediaAssetId != null && photoMediaAssetId is! int) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'نوع یکی از فیلدهای ارسالی معتبر نیست.'},
    );
  }

  try {
    final profile = await memorialProfileService.createProfile(
      userId: userId,
      fullName: fullName,
      relationship: relationship,
      birthDate: birthDate as String?,
      deathDate: deathDate as String?,
      memorialText: memorialText as String?,
      graveAddress: graveAddress as String?,
      photoMediaAssetId: photoMediaAssetId as int?,
    );

    return Response.json(
      statusCode: 201,
      body: {
        'message': 'پروفایل با موفقیت ایجاد شد.',
        'data': profile,
      },
    );
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
      'Failed to create memorial profile',
      error: error,
      stackTrace: stackTrace,
      name: 'memorial_profiles.create',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'ایجاد پروفایل با خطا مواجه شد.'},
    );
  }
}

Future<Response> _searchProfiles(RequestContext context) async {
  final query = context.request.uri.queryParameters['q'];

  if (query == null) {
    return Response.json(
      statusCode: 400,
      body: {'error': 'عبارت جست‌وجو الزامی است.'},
    );
  }

  try {
    final profiles = await memorialProfileService.searchProfiles(
      query: query,
    );

    return Response.json(
      body: {'data': profiles},
    );
  } on MemorialProfileException catch (error) {
    return Response.json(
      statusCode: 400,
      body: {'error': error.message},
    );
  } catch (error, stackTrace) {
    developer.log(
      'Failed to search memorial profiles',
      error: error,
      stackTrace: stackTrace,
      name: 'memorial_profiles.search',
    );

    return Response.json(
      statusCode: 500,
      body: {'error': 'جست‌وجوی پروفایل‌ها با خطا مواجه شد.'},
    );
  }
}
