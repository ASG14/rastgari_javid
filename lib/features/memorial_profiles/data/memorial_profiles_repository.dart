import '../../../core/network/api_client.dart';
import '../models/memorial_profile.dart';

class MemorialProfilesRepository {
  MemorialProfilesRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  /// دریافت فهرست عزیزان آسمانی کاربر واردشده
  Future<List<MemorialProfile>> getMyProfiles({required String token}) async {
    _validateToken(token);

    final response = await _apiClient.get(
      '/memorial-profiles/user',
      token: token,
    );

    return _parseProfileList(response);
  }

  /// دریافت فهرست عزیزان آسمانی یک کاربر دیگر
  Future<List<MemorialProfile>> getUserProfiles({
    required int userId,
    required String token,
  }) async {
    _validateUserId(userId);
    _validateToken(token);

    final response = await _apiClient.get(
      '/memorial-profiles/users/$userId',
      token: token,
    );

    return _parseProfileList(response);
  }

  /// جست‌وجوی پروفایل‌های عزیزان آسمانی
  Future<List<MemorialProfile>> searchProfiles({
    required String query,
    required String token,
  }) async {
    _validateToken(token);

    final normalizedQuery = query.trim();

    if (normalizedQuery.length < 2) {
      throw const ApiException('برای جست‌وجو حداقل دو حرف وارد کنید.');
    }

    final response = await _apiClient.get(
      '/memorial-profiles?q=${Uri.encodeQueryComponent(normalizedQuery)}',
      token: token,
    );

    return _parseProfileList(response);
  }

  /// دریافت جزئیات یک پروفایل
  Future<MemorialProfile> getProfile({
    required int profileId,
    required String token,
  }) async {
    _validateProfileId(profileId);
    _validateToken(token);

    final response = await _apiClient.get(
      '/memorial-profiles/$profileId',
      token: token,
    );

    return _parseProfile(response);
  }

  /// ایجاد پروفایل عزیز آسمانی
  Future<MemorialProfile> createProfile({
    required String fullName,
    required String relationship,
    required String token,
    String? birthDate,
    String? deathDate,
    String? memorialText,
    String? graveAddress,
    int? photoMediaAssetId,
  }) async {
    _validateToken(token);
    _validateFullName(fullName);

    final response = await _apiClient.post(
      '/memorial-profiles',
      token: token,
      body: {
        'full_name': fullName.trim(),
        'relationship': relationship,
        'birth_date': _normalizeOptionalText(birthDate),
        'death_date': _normalizeOptionalText(deathDate),
        'memorial_text': _normalizeOptionalText(memorialText),
        'grave_address': _normalizeOptionalText(graveAddress),
        'photo_media_asset_id': photoMediaAssetId,
      },
    );

    return _parseProfile(response);
  }

  /// ویرایش پروفایل
  Future<MemorialProfile> updateProfile({
    required int profileId,
    required String fullName,
    required String token,
    String? birthDate,
    String? deathDate,
    String? memorialText,
    String? graveAddress,
    int? photoMediaAssetId,
  }) async {
    _validateProfileId(profileId);
    _validateToken(token);
    _validateFullName(fullName);

    final response = await _apiClient.put(
      '/memorial-profiles/$profileId',
      token: token,
      body: {
        'full_name': fullName.trim(),
        'birth_date': _normalizeOptionalText(birthDate),
        'death_date': _normalizeOptionalText(deathDate),
        'memorial_text': _normalizeOptionalText(memorialText),
        'grave_address': _normalizeOptionalText(graveAddress),
        'photo_media_asset_id': photoMediaAssetId,
      },
    );

    return _parseProfile(response);
  }

  /// حذف پروفایل
  Future<void> deleteProfile({
    required int profileId,
    required String token,
  }) async {
    _validateProfileId(profileId);
    _validateToken(token);

    await _apiClient.delete('/memorial-profiles/$profileId', token: token);
  }

  /// دنبال‌کردن پروفایل
  Future<MemorialMembership> followProfile({
    required int profileId,
    required String relationship,
    required String token,
  }) async {
    _validateProfileId(profileId);
    _validateToken(token);

    final response = await _apiClient.post(
      '/memorial-profiles/$profileId/follow',
      token: token,
      body: {'relationship': relationship},
    );

    final data = response['data'];

    if (data is! Map) {
      throw const ApiException('اطلاعات عضویت در پروفایل معتبر نیست.');
    }

    return MemorialMembership.fromJson(Map<String, dynamic>.from(data));
  }

  /// لغو دنبال‌کردن پروفایل
  Future<void> unfollowProfile({
    required int profileId,
    required String token,
  }) async {
    _validateProfileId(profileId);
    _validateToken(token);

    await _apiClient.delete(
      '/memorial-profiles/$profileId/follow',
      token: token,
    );
  }

  List<MemorialProfile> _parseProfileList(Map<String, dynamic> response) {
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

      return MemorialProfile.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  MemorialProfile _parseProfile(Map<String, dynamic> response) {
    final data = response['data'];

    if (data is! Map) {
      throw const ApiException('اطلاعات پروفایل عزیز آسمانی معتبر نیست.');
    }

    final profile = MemorialProfile.fromJson(Map<String, dynamic>.from(data));

    if (profile.id < 1 || profile.fullName.isEmpty) {
      throw const FormatException('اطلاعات اصلی پروفایل ناقص است.');
    }

    return profile;
  }

  String? _normalizeOptionalText(String? value) {
    if (value == null) return null;

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  void _validateToken(String token) {
    if (token.trim().isEmpty) {
      throw const ApiException(
        'برای انجام این عملیات ابتدا وارد حساب کاربری شوید.',
      );
    }
  }

  void _validateProfileId(int profileId) {
    if (profileId < 1) {
      throw const ApiException('شناسه پروفایل معتبر نیست.');
    }
  }

  void _validateUserId(int userId) {
    if (userId < 1) {
      throw const ApiException('شناسه کاربر معتبر نیست.');
    }
  }

  void _validateFullName(String fullName) {
    final normalized = fullName.trim();

    if (normalized.isEmpty || normalized.length > 150) {
      throw const ApiException(
        'نام و نام خانوادگی الزامی است و حداکثر ۱۵۰ کاراکتر دارد.',
      );
    }
  }
}
