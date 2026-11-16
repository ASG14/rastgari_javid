class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.bio,
    this.avatarStorageKey,
    this.createdAt,
    this.isPrivate = false,
  });

  final int id;
  final String username;
  final String displayName;
  final String? email;
  final String? bio;
  final String? avatarStorageKey;
  final String? createdAt;
  final bool isPrivate;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final idValue = json['id'];
    final usernameValue = json['username'];
    final displayNameValue = json['display_name'];
    final isPrivateValue = json['is_private'];

    if (idValue is! num ||
        usernameValue is! String ||
        displayNameValue is! String) {
      throw const FormatException(
        'ساختار اطلاعات پایه کاربر در پاسخ سرور معتبر نیست.',
      );
    }

    if (isPrivateValue != null && isPrivateValue is! bool) {
      throw const FormatException('وضعیت حریم خصوصی حساب کاربر معتبر نیست.');
    }

    return AuthUser(
      id: idValue.toInt(),
      username: usernameValue,
      displayName: displayNameValue,
      email: _optionalString(json['email']),
      bio: _optionalString(json['bio']),
      avatarStorageKey: _optionalString(json['avatar_storage_key']),
      createdAt: _optionalString(json['created_at']),
      isPrivate: isPrivateValue as bool? ?? false,
    );
  }

  static String? _optionalString(Object? value) {
    if (value is! String) return null;

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
