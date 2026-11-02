
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';

class NotificationRepository {
  NotificationRepository({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  }) : _apiClient = apiClient ?? ApiClient(),
       _tokenStorage = tokenStorage ?? TokenStorage();

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 50,
  }) async {
    final token = await _requireToken();

    final response = await _apiClient.get(
      '/notifications?limit=$limit',
      token: token,
    );

    final data = response['data'];

    if (data is! List) {
      throw const ApiException('ساختار فهرست اعلان‌ها معتبر نیست.');
    }

    return data.map((item) {
      if (item is! Map) {
        throw const ApiException('ساختار یکی از اعلان‌ها معتبر نیست.');
      }

      return Map<String, dynamic>.from(item);
    }).toList();
  }

  Future<int> getUnreadCount() async {
    final token = await _tokenStorage.readToken();

    if (token == null || token.isEmpty) {
      return 0;
    }

    final response = await _apiClient.get(
      '/notifications/unread-count',
      token: token,
    );

    final data = response['data'];

    if (data is! Map<String, dynamic>) {
      throw const ApiException(
        'ساختار پاسخ تعداد اعلان‌های خوانده‌نشده نامعتبر است.',
      );
    }

    final count = data['unread_count'];

    if (count is num && count >= 0) {
      return count.toInt();
    }

    throw const ApiException(
      'تعداد اعلان‌های خوانده‌نشده در پاسخ سرور معتبر نیست.',
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final token = await _requireToken();

    await _apiClient.patch(
      '/notifications/$notificationId/read',
      token: token,
    );
  }

  Future<String> _requireToken() async {
    final token = await _tokenStorage.readToken();

    if (token == null || token.isEmpty) {
      throw const ApiException(
        'برای مشاهده یا تغییر اعلان‌ها باید وارد حساب کاربری شوید.',
        statusCode: 401,
      );
    }

    return token;
  }
}
