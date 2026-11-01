
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
