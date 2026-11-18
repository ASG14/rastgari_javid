import '../../../core/network/api_client.dart';

class UserProfileRepository {
  UserProfileRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> getUserProfile({
    required int userId,
    required String token,
  }) async {
    _validateUserId(userId);
    _validateToken(token);

    final response = await _apiClient.get('/users/$userId', token: token);

    final data = response['data'];

    if (data is! Map) {
      throw const FormatException('ساختار اطلاعات پروفایل معتبر نیست.');
    }

    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> followUser({
    required int userId,
    required String token,
  }) async {
    _validateUserId(userId);
    _validateToken(token);

    return _apiClient.post('/users/$userId/follow', token: token);
  }

  Future<Map<String, dynamic>> unfollowUser({
    required int userId,
    required String token,
  }) async {
    _validateUserId(userId);
    _validateToken(token);

    return _apiClient.delete('/users/$userId/follow', token: token);
  }

  Future<Map<String, dynamic>> cancelFollowRequest({
    required int requestId,
    required String token,
  }) async {
    if (requestId < 1) {
      throw const ApiException('شناسه درخواست معتبر نیست.');
    }

    _validateToken(token);

    return _apiClient.delete(
      '/users/me/follow-requests/$requestId',
      token: token,
    );
  }

  Future<int?> findOutgoingRequestId({
    required int targetUserId,
    required String token,
  }) async {
    _validateUserId(targetUserId);
    _validateToken(token);

    final response = await _apiClient.get(
      '/users/me/follow-requests/outgoing?limit=100&offset=0',
      token: token,
    );

    final data = response['data'];

    if (data is! Map || data['items'] is! List) {
      throw const FormatException('ساختار درخواست‌های دوستی خروجی معتبر نیست.');
    }

    for (final item in data['items'] as List) {
      if (item is! Map) continue;

      final user = item['user'];
      if (user is! Map) continue;

      final userId = _readInt(user['id']);
      if (userId == targetUserId) {
        return _readInt(item['request_id']);
      }
    }

    return null;
  }

  Future<Map<String, dynamic>> getFollowers({
    required int userId,
    required String token,
    int limit = 20,
    int offset = 0,
  }) {
    return _getConnections(
      userId: userId,
      token: token,
      endpoint: 'followers',
      limit: limit,
      offset: offset,
    );
  }

  Future<Map<String, dynamic>> getFollowing({
    required int userId,
    required String token,
    int limit = 20,
    int offset = 0,
  }) {
    return _getConnections(
      userId: userId,
      token: token,
      endpoint: 'following',
      limit: limit,
      offset: offset,
    );
  }

  Future<Map<String, dynamic>> _getConnections({
    required int userId,
    required String token,
    required String endpoint,
    required int limit,
    required int offset,
  }) async {
    _validateUserId(userId);
    _validateToken(token);

    if (limit < 1 || limit > 100 || offset < 0) {
      throw const ApiException('پارامترهای صفحه‌بندی معتبر نیستند.');
    }

    final uri = Uri(
      path: '/users/$userId/$endpoint',
      queryParameters: {'limit': limit.toString(), 'offset': offset.toString()},
    );

    final response = await _apiClient.get(uri.toString(), token: token);

    final data = response['data'];

    if (data is! Map) {
      throw const FormatException('ساختار فهرست کاربران معتبر نیست.');
    }

    return Map<String, dynamic>.from(data);
  }

  void _validateUserId(int userId) {
    if (userId < 1) {
      throw const ApiException('شناسه کاربر معتبر نیست.');
    }
  }

  void _validateToken(String token) {
    if (token.isEmpty) {
      throw const ApiException(
        'برای انجام این عملیات ابتدا وارد حساب شوید.',
        statusCode: 401,
      );
    }
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
