class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.createdAt,
  });

  final int id;
  final String username;
  final String displayName;
  final String? email;
  final String? createdAt;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      email: json['email'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
