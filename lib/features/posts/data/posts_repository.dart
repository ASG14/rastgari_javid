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

  Future<Post> createPublicPost({
    required String content,
    required String token,
  }) async {
    final normalizedContent = content.trim();

    if (normalizedContent.isEmpty) {
      throw const ApiException('متن پست الزامی است.');
    }

    if (normalizedContent.length > 10000) {
      throw const ApiException(
        'متن پست نمی‌تواند بیشتر از ۱۰۰۰۰ کاراکتر باشد.',
      );
    }

    final response = await _apiClient.post(
      '/posts',
      token: token,
      body: {'content': normalizedContent},
    );

    final data = response['data'];

    if (data is! Map) {
      throw const ApiException('ساختار پاسخ انتشار پست از سرور معتبر نیست.');
    }

    return Post.fromJson(Map<String, dynamic>.from(data));
  }
}
