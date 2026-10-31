import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../models/auth_response.dart';
import '../models/auth_user.dart';

class AuthRepository {
  AuthRepository({ApiClient? apiClient, TokenStorage? tokenStorage})
    : _apiClient = apiClient ?? ApiClient(),
      _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AuthUser> register({
    required String username,
    required String displayName,
    required String password,
    String? email,
  }) async {
    final response = await _apiClient.post(
      '/auth/register',
      body: {
        'username': username,
        'display_name': displayName,
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
    );

    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw const ApiException('ساختار پاسخ ثبت‌نام نامعتبر است.');
    }

    return AuthUser.fromJson(data);
  }

  Future<AuthResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/auth/login',
      body: {'username': username, 'password': password},
    );

    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw const ApiException('ساختار پاسخ ورود نامعتبر است.');
    }

    final authResponse = AuthResponse.fromJson(data);

    await _tokenStorage.saveToken(authResponse.accessToken);

    return authResponse;
  }

  /// اطلاعات کاربر را با توکن ذخیره‌شده از سرور دریافت می‌کند.
  ///
  /// اگر توکنی وجود نداشته باشد یا سرور آن را رد کند، null برمی‌گرداند.
  /// خطاهای دیگر، مانند قطع بودن سرور، به فراخواننده منتقل می‌شوند.
  Future<AuthUser?> getCurrentUser() async {
    final token = await _tokenStorage.readToken();

    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _apiClient.get('/auth/me', token: token);

      final data = response['data'];

      if (data is! Map<String, dynamic>) {
        throw const ApiException(
          'ساختار پاسخ دریافت اطلاعات کاربر نامعتبر است.',
        );
      }

      return AuthUser.fromJson(data);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _tokenStorage.deleteToken();
        return null;
      }

      rethrow;
    }
  }

  Future<void> logout() async {
    await _tokenStorage.deleteToken();
  }

  Future<String?> readAccessToken() {
    return _tokenStorage.readToken();
  }
}
