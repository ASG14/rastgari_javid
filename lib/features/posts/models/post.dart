import 'post_author.dart';

class Post {
  const Post({
    required this.id,
    required this.author,
    required this.content,
    required this.createdAt,
    this.mediaUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
  });

  final String id;
  final PostAuthor author;
  final String content;
  final DateTime createdAt;
  final String? mediaUrl;
  final int likeCount;
  final int commentCount;
  final bool isLiked;

  factory Post.fromJson(Map<String, dynamic> json) {
    final authorJson = json['author'];

    if (authorJson is! Map) {
      throw const FormatException('اطلاعات نویسنده پست معتبر نیست.');
    }

    final publishedAt = json['published_at'];
    final createdAt = json['created_at'];

    final dateString = publishedAt is String && publishedAt.isNotEmpty
        ? publishedAt
        : createdAt;

    if (dateString is! String) {
      throw const FormatException('تاریخ انتشار پست معتبر نیست.');
    }

    final parsedDate = DateTime.tryParse(dateString);

    if (parsedDate == null) {
      throw const FormatException('تاریخ انتشار پست قابل پردازش نیست.');
    }

    final mediaUrl = json['media_url'];

    return Post(
      id: json['id'].toString(),
      author: PostAuthor.fromJson(Map<String, dynamic>.from(authorJson)),
      content: json['content'] is String ? json['content'] as String : '',
      createdAt: parsedDate.toLocal(),
      mediaUrl: mediaUrl is String ? mediaUrl : null,
      likeCount: _readInt(json['likes_count']),
      commentCount: _readInt(json['comments_count']),
      isLiked: json['is_liked'] == true,
    );
  }

  static int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }

  Post copyWith({
    String? id,
    PostAuthor? author,
    String? content,
    DateTime? createdAt,
    String? mediaUrl,
    int? likeCount,
    int? commentCount,
    bool? isLiked,
  }) {
    return Post(
      id: id ?? this.id,
      author: author ?? this.author,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
