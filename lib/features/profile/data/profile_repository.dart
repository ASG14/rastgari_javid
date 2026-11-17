import '../../../core/network/api_client.dart';

class ProfileRepository {
  ProfileRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// دریافت اطلاعات پروفایل و آمار کاربر
  Future<Map<String, dynamic>> getUserProfile({
    required int userId,
    required String token,
  }) async {
    if (userId < 1) {
      throw const ApiException('شناسه کاربر معتبر نیست.');
    }

    if (token.isEmpty) {
      throw const ApiException(
        'برای دریافت اطلاعات پروفایل ابتدا وارد حساب شوید.',
      );
    }

    final response = await _apiClient.get('/users/$userId', token: token);

    // طبق پیاده‌سازی واقعی Backend، اطلاعات پروفایل
    // مستقیماً داخل data قرار دارد، نه data.profile.
    final data = response['data'];

    if (data is! Map) {
      throw const ApiException('ساختار پاسخ اطلاعات پروفایل معتبر نیست.');
    }

    return Map<String, dynamic>.from(data);
  }

  /// دریافت فهرست عزیزان آسمانی کاربر واردشده
  Future<List<Map<String, dynamic>>> getMyMemorialProfiles({
    required String token,
  }) async {
    if (token.isEmpty) {
      throw const ApiException(
        'برای دریافت عزیزان آسمانی ابتدا وارد حساب شوید.',
      );
    }

    final response = await _apiClient.get(
      '/memorial-profiles/user',
      token: token,
    );

    final data = response['data'];

    if (data is! List) {
      throw const ApiException('ساختار فهرست عزیزان آسمانی معتبر نیست.');
    }

    return data.map((item) {
      if (item is! Map) {
        throw const FormatException(
          'اطلاعات یکی از پروفایل‌های یادبود معتبر نیست.',
        );
      }

      return Map<String, dynamic>.from(item);
    }).toList();
  }
}
