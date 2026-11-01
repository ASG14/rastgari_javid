import '../../posts/models/post_author.dart';

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.author,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final PostAuthor author;
  final String content;
  final DateTime createdAt;

  factory Comment.fromJson(Map<String, dynamic> json) {
    final authorJson = json['author'];
    final createdAtValue = json['created_at'];

    if (authorJson is! Map) {
      throw const FormatException('اطلاعات نویسنده دیدگاه معتبر نیست.');
    }

    if (createdAtValue is! String) {
      throw const FormatException('تاریخ دیدگاه معتبر نیست.');
    }

    final parsedDate = DateTime.tryParse(createdAtValue);

    if (parsedDate == null) {
      throw const FormatException('تاریخ دیدگاه قابل پردازش نیست.');
    }

    return Comment(
      id: json['id'].toString(),
      postId: json['post_id'].toString(),
      author: PostAuthor.fromJson(Map<String, dynamic>.from(authorJson)),
      content: json['content'] is String ? json['content'] as String : '',
      createdAt: parsedDate.toLocal(),
    );
  }
}
