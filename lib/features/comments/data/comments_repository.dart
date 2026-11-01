import '../../../core/network/api_client.dart';
import '../models/comment.dart';

class CommentsRepository {
  CommentsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<List<Comment>> getPostComments({
    required String postId,
    required String token,
  }) async {
    final response = await _apiClient.get(
      '/posts/${Uri.encodeComponent(postId)}/comments',
      token: token,
    );

    final data = response['data'];

    if (data is! List) {
      throw const FormatException(
        'ساختار فهرست دیدگاه‌ها در پاسخ سرور معتبر نیست.',
      );
    }

    return data.map((item) {
      if (item is! Map) {
        throw const FormatException('اطلاعات یکی از دیدگاه‌ها معتبر نیست.');
      }

      return Comment.fromJson(Map<String, dynamic>.from(item));
    }).toList();
  }

  Future<Comment> createComment({
    required String postId,
    required String content,
    required String token,
  }) async {
    final normalizedContent = content.trim();

    if (normalizedContent.isEmpty) {
      throw const ApiException('متن دیدگاه الزامی است.');
    }

    if (normalizedContent.length > 5000) {
      throw const ApiException(
        'متن دیدگاه نمی‌تواند بیشتر از ۵۰۰۰ کاراکتر باشد.',
      );
    }

    final response = await _apiClient.post(
      '/posts/${Uri.encodeComponent(postId)}/comments',
      token: token,
      body: {'content': normalizedContent},
    );

    final data = response['data'];

    if (data is! Map) {
      throw const ApiException('ساختار پاسخ ثبت دیدگاه از سرور معتبر نیست.');
    }

    return Comment.fromJson(Map<String, dynamic>.from(data));
  }
}
