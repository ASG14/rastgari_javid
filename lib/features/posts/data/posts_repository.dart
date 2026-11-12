import '../../../core/network/api_client.dart';
import '../models/post.dart';

class PostsRepository {
  PostsRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<PostFeedPage> getPublicPosts({
    String? token,
    int limit = 20,
    String? cursor,
  }) async {
    final queryParameters = <String, String>{
      'limit': limit.toString(),
      if (cursor != null) 'cursor': cursor,
    };

    final path = Uri(
      path: '/posts',
      queryParameters: queryParameters,
    ).toString();

    final response = await _apiClient.get(path, token: token);

    final data = response['data'];
    final pagination = response['pagination'];

    if (data is! List) {
      throw const FormatException(
        'ساختار فهرست پست‌ها در پاسخ سرور معتبر نیست.',
      );
    }

    if (pagination is! Map) {
      throw const FormatException(
        'اطلاعات صفحه‌بندی فید در پاسخ سرور معتبر نیست.',
      );
    }

    final paginationData = Map<String, dynamic>.from(pagination);
    final hasMore = paginationData['has_more'];
    final nextCursor = paginationData['next_cursor'];

    if (hasMore is! bool) {
      throw const FormatException(
        'وضعیت صفحه بعد در پاسخ سرور معتبر نیست.',
      );
    }

    if (nextCursor != null && nextCursor is! String) {
      throw const FormatException(
        'نشانگر صفحه بعد در پاسخ سرور معتبر نیست.',
      );
    }

    if (hasMore && (nextCursor == null || nextCursor.isEmpty)) {
      throw const FormatException(
        'سرور وجود صفحه بعد را اعلام کرده اما نشانگر آن معتبر نیست.',
      );
    }

    final posts = data.map((item) {
      if (item is! Map) {
        throw const FormatException(
          'اطلاعات یکی از پست‌ها معتبر نیست.',
        );
      }

      return Post.fromJson(Map<String, dynamic>.from(item));
    }).toList();

    return PostFeedPage(
      posts: posts,
      hasMore: hasMore,
      nextCursor: nextCursor as String?,
    );
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
      throw const ApiException(
        'ساختار پاسخ انتشار پست از سرور معتبر نیست.',
      );
    }

    return Post.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Map<String, dynamic>> setPostLike({
    required String postId,
    required bool isLiked,
    required String token,
  }) async {
    final path = '/posts/${Uri.encodeComponent(postId)}/like';

    final response = isLiked
        ? await _apiClient.post(path, token: token)
        : await _apiClient.delete(path, token: token);

    final data = response['data'];

    if (data is! Map) {
      throw const ApiException(
        'ساختار پاسخ تغییر وضعیت همدلی معتبر نیست.',
      );
    }

    return Map<String, dynamic>.from(data);
  }
}

/// Contains one page of posts and its pagination state.
class PostFeedPage {
  const PostFeedPage({
    required this.posts,
    required this.hasMore,
    required this.nextCursor,
  });

  final List<Post> posts;
  final bool hasMore;
  final String? nextCursor;
}
