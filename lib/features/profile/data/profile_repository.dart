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
    _validateUserId(userId);
    _validateToken(token);

    final response = await _apiClient.get('/users/$userId', token: token);

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
    _validateToken(token);

    final response = await _apiClient.get(
      '/memorial-profiles/user',
      token: token,
    );

    return _parseMemorialProfiles(response);
  }

  /// دریافت عزیزان آسمانی یک کاربر دیگر
  ///
  /// دسترسی به این اطلاعات توسط Backend و بر اساس
  /// قوانین حریم خصوصی حساب مقصد کنترل می‌شود.
  Future<List<Map<String, dynamic>>> getUserMemorialProfiles({
    required int userId,
    required String token,
  }) async {
    _validateUserId(userId);
    _validateToken(token);

    final response = await _apiClient.get(
      '/memorial-profiles/users/$userId',
      token: token,
    );

    return _parseMemorialProfiles(response);
  }

  List<Map<String, dynamic>> _parseMemorialProfiles(
    Map<String, dynamic> response,
  ) {
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

  void _validateUserId(int userId) {
    if (userId < 1) {
      throw const ApiException('شناسه کاربر معتبر نیست.');
    }
  }

  void _validateToken(String token) {
    if (token.isEmpty) {
      throw const ApiException('برای انجام این عملیات ابتدا وارد حساب شوید.');
    }
  }
}
