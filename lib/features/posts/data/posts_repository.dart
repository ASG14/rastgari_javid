import '../../../core/network/api_client.dart';
import '../models/post.dart';

class PostsRepository {
  PostsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Post>> getPublicPosts() async {
    final response = await _apiClient.get('/posts');
    final data = response['data'];

    if (data is! List) {
      throw const FormatException(
        'ساختار فهرست پست‌ها در پاسخ سرور معتبر نیست.',
      );
    }

    return data.map((item) {
      if (item is! Map) {
        throw const FormatException('اطلاعات یکی از پست‌ها معتبر نیست.');
      }

      return Post.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }
}
