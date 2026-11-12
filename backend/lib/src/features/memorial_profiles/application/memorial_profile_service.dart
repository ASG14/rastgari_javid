import 'package:backend/src/features/memorial_profiles/data/memorial_profile_repository.dart';

/// Handles application rules for memorial profiles.
class MemorialProfileService {
  /// Creates the service with its repository.
  MemorialProfileService(this._repository);

  final MemorialProfileRepository _repository;

  static const Set<String> _relationships = {
    'mother',
    'father',
    'sister',
    'brother',
    'child',
    'spouse',
    'friend',
    'other',
  };

  /// Creates a memorial profile for the authenticated user.
  Future<Map<String, dynamic>> createProfile({
    required int userId,
    required String fullName,
    required String relationship,
    String? birthDate,
    String? deathDate,
    String? memorialText,
    String? graveAddress,
    int? photoMediaAssetId,
  }) async {
    if (userId < 1) {
      throw const MemorialProfileException('کاربر معتبر نیست.');
    }

    final normalizedName = fullName.trim();

    if (normalizedName.isEmpty || normalizedName.length > 150) {
      throw const MemorialProfileException(
        'نام و نام خانوادگی الزامی است و حداکثر ۱۵۰ کاراکتر دارد.',
      );
    }

    if (!_relationships.contains(relationship)) {
      throw const MemorialProfileException(
        'نسبت انتخاب‌شده با مرحوم معتبر نیست.',
      );
    }

    final parsedBirthDate = _parseDate(birthDate, 'تاریخ تولد');
    final parsedDeathDate = _parseDate(deathDate, 'تاریخ وفات');

    if (parsedBirthDate != null &&
        parsedDeathDate != null &&
        parsedDeathDate.isBefore(parsedBirthDate)) {
      throw const MemorialProfileException(
        'تاریخ وفات نمی‌تواند قبل از تاریخ تولد باشد.',
      );
    }

    final normalizedMemorialText = memorialText?.trim();
    if (normalizedMemorialText != null &&
        normalizedMemorialText.length > 10000) {
      throw const MemorialProfileException(
        'دل‌نوشته نمی‌تواند بیشتر از ۱۰۰۰۰ کاراکتر باشد.',
      );
    }

    final normalizedGraveAddress = graveAddress?.trim();
    if (normalizedGraveAddress != null && normalizedGraveAddress.length > 500) {
      throw const MemorialProfileException(
        'نشانی مزار نمی‌تواند بیشتر از ۵۰۰ کاراکتر باشد.',
      );
    }

    if (photoMediaAssetId != null && photoMediaAssetId < 1) {
      throw const MemorialProfileException('شناسه تصویر معتبر نیست.');
    }

    return _repository.createProfile(
      userId: userId,
      fullName: normalizedName,
      relationship: relationship,
      birthDate: parsedBirthDate,
      deathDate: parsedDeathDate,
      memorialText: _emptyToNull(normalizedMemorialText),
      graveAddress: _emptyToNull(normalizedGraveAddress),
      photoMediaAssetId: photoMediaAssetId,
    );
  }

  /// Searches memorial profiles by their names.
  Future<List<Map<String, dynamic>>> searchProfiles({
    required String query,
    int limit = 20,
  }) async {
    final normalizedQuery = query.trim();

    if (normalizedQuery.length < 2) {
      throw const MemorialProfileException(
        'برای جست‌وجو حداقل دو حرف وارد کنید.',
      );
    }

    if (normalizedQuery.length > 150) {
      throw const MemorialProfileException(
        'عبارت جست‌وجو بیش از حد طولانی است.',
      );
    }

    return _repository.searchProfiles(
      query: normalizedQuery,
      limit: limit.clamp(1, 50),
    );
  }

  /// Updates a memorial profile owned by the authenticated user.
  Future<Map<String, dynamic>> updateProfile({
    required int profileId,
    required int userId,
    required String fullName,
    String? birthDate,
    String? deathDate,
    String? memorialText,
    String? graveAddress,
    int? photoMediaAssetId,
  }) async {
    if (profileId < 1 || userId < 1) {
      throw const MemorialProfileException(
        'شناسه پروفایل یا کاربر معتبر نیست.',
      );
    }

    final normalizedName = fullName.trim();

    if (normalizedName.isEmpty || normalizedName.length > 150) {
      throw const MemorialProfileException(
        'نام و نام خانوادگی الزامی است و حداکثر ۱۵۰ کاراکتر دارد.',
      );
    }

    final parsedBirthDate = _parseDate(birthDate, 'تاریخ تولد');
    final parsedDeathDate = _parseDate(deathDate, 'تاریخ وفات');

    if (parsedBirthDate != null &&
        parsedDeathDate != null &&
        parsedDeathDate.isBefore(parsedBirthDate)) {
      throw const MemorialProfileException(
        'تاریخ وفات نمی‌تواند قبل از تاریخ تولد باشد.',
      );
    }

    final normalizedMemorialText = memorialText?.trim();
    if (normalizedMemorialText != null &&
        normalizedMemorialText.length > 10000) {
      throw const MemorialProfileException(
        'دل‌نوشته نمی‌تواند بیشتر از ۱۰۰۰۰ کاراکتر باشد.',
      );
    }

    final normalizedGraveAddress = graveAddress?.trim();
    if (normalizedGraveAddress != null && normalizedGraveAddress.length > 500) {
      throw const MemorialProfileException(
        'نشانی مزار نمی‌تواند بیشتر از ۵۰۰ کاراکتر باشد.',
      );
    }

    if (photoMediaAssetId != null && photoMediaAssetId < 1) {
      throw const MemorialProfileException('شناسه تصویر معتبر نیست.');
    }

    final profile = await _repository.updateProfile(
      profileId: profileId,
      userId: userId,
      fullName: normalizedName,
      birthDate: parsedBirthDate,
      deathDate: parsedDeathDate,
      memorialText: _emptyToNull(normalizedMemorialText),
      graveAddress: _emptyToNull(normalizedGraveAddress),
      photoMediaAssetId: photoMediaAssetId,
    );

    if (profile == null) {
      throw const MemorialProfileException(
        'پروفایل پیدا نشد یا شما سازنده آن نیستید.',
      );
    }

    return profile;
  }

  /// Soft-deletes a profile owned by the authenticated user.
  Future<void> deleteProfile({
    required int profileId,
    required int userId,
  }) async {
    if (profileId < 1 || userId < 1) {
      throw const MemorialProfileException(
        'شناسه پروفایل یا کاربر معتبر نیست.',
      );
    }

    final deleted = await _repository.deleteProfile(
      profileId: profileId,
      userId: userId,
    );

    if (!deleted) {
      throw const MemorialProfileException(
        'پروفایل پیدا نشد یا شما سازنده آن نیستید.',
      );
    }
  }

  /// Returns memorial profiles created or followed by the user.
  Future<List<Map<String, dynamic>>> getUserProfiles({
    required int userId,
  }) async {
    if (userId < 1) {
      throw const MemorialProfileException('شناسه کاربر معتبر نیست.');
    }

    return _repository.getUserProfiles(userId: userId);
  }

  /// Unfollows a memorial profile.
  Future<void> unfollowProfile({
    required int profileId,
    required int userId,
  }) async {
    if (profileId < 1 || userId < 1) {
      throw const MemorialProfileException(
        'شناسه پروفایل یا کاربر معتبر نیست.',
      );
    }

    final unfollowed = await _repository.unfollowProfile(
      profileId: profileId,
      userId: userId,
    );

    if (!unfollowed) {
      throw const MemorialProfileException(
        'امکان لغو دنبال‌کردن این پروفایل وجود ندارد.',
      );
    }
  }

  DateTime? _parseDate(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return null;

    final normalizedValue = value.trim();

    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(normalizedValue)) {
      throw MemorialProfileException(
        '$fieldName باید با قالب YYYY-MM-DD ارسال شود.',
      );
    }

    final parsed = DateTime.tryParse(normalizedValue);

    if (parsed == null ||
        parsed.toIso8601String().substring(0, 10) != normalizedValue) {
      throw MemorialProfileException('$fieldName معتبر نیست.');
    }

    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  String? _emptyToNull(String? value) {
    if (value == null || value.isEmpty) return null;
    return value;
  }

  /// Follows a memorial profile using the user's own relationship.
  Future<Map<String, dynamic>> followProfile({
    required int profileId,
    required int userId,
    required String relationship,
  }) async {
    if (profileId < 1 || userId < 1) {
      throw const MemorialProfileException(
        'شناسه پروفایل یا کاربر معتبر نیست.',
      );
    }

    if (!_relationships.contains(relationship)) {
      throw const MemorialProfileException(
        'نسبت انتخاب‌شده با مرحوم معتبر نیست.',
      );
    }

    final membership = await _repository.followProfile(
      profileId: profileId,
      userId: userId,
      relationship: relationship,
    );

    if (membership == null) {
      throw const MemorialProfileException(
        'پروفایل موردنظر پیدا نشد.',
      );
    }

    return membership;
  }

  /// Retrieves a memorial profile for an authenticated user.
  Future<Map<String, dynamic>?> getProfileById({
    required int profileId,
    required int userId,
  }) async {
    if (profileId < 1 || userId < 1) {
      throw const MemorialProfileException(
        'شناسه پروفایل یا کاربر معتبر نیست.',
      );
    }

    return _repository.getProfileById(
      profileId: profileId,
      userId: userId,
    );
  }
}

/// Represents a memorial-profile validation error.
class MemorialProfileException implements Exception {
  /// Creates a validation exception.
  const MemorialProfileException(this.message);

  /// User-facing validation message.
  final String message;

  @override
  String toString() => message;
}
