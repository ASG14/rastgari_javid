import 'auth_user.dart';

class AuthResponse {
  const AuthResponse({
    required this.user,
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
  });

  final AuthUser user;
  final String accessToken;
  final String tokenType;
  final int expiresIn;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
    );
  }
}
