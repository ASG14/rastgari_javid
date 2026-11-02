
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.postId,
    required this.createdAt,
    required this.isRead,
    this.commentId,
    this.actorId,
    this.actorUsername,
    this.actorDisplayName,
    this.readAt,
  });

  final String id;
  final String type;
  final String postId;
  final String? commentId;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isRead;
  final String? actorId;
  final String? actorUsername;
  final String? actorDisplayName;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final createdAtString = json['created_at'];

    if (createdAtString is! String) {
      throw const FormatException('تاریخ اعلان معتبر نیست.');
    }

    final createdAt = DateTime.tryParse(createdAtString);

    if (createdAt == null) {
      throw const FormatException('تاریخ اعلان قابل پردازش نیست.');
    }

    final actor = json['actor'];

    if (actor != null && actor is! Map) {
      throw const FormatException('اطلاعات فرستنده اعلان معتبر نیست.');
    }

    final actorData = actor is Map
        ? Map<String, dynamic>.from(actor)
        : <String, dynamic>{};

    final readAtString = json['read_at'];

    return NotificationItem(
      id: json['id'].toString(),
      type: json['type'] as String? ?? '',
      postId: json['post_id'].toString(),
      commentId: json['comment_id']?.toString(),
      createdAt: createdAt.toLocal(),
      readAt: readAtString is String
          ? DateTime.tryParse(readAtString)?.toLocal()
          : null,
      isRead: json['is_read'] == true,
      actorId: actorData['id']?.toString(),
      actorUsername: actorData['username'] as String?,
      actorDisplayName: actorData['display_name'] as String?,
    );
  }

  String get actorName {
    final displayName = actorDisplayName?.trim();

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final username = actorUsername?.trim();

    if (username != null && username.isNotEmpty) {
      return '@$username';
    }

    return 'یک کاربر';
  }

  String get message {
    switch (type) {
      case 'post_like':
        return '$actorName با نوشته‌ات همدلی کرده است.';
      case 'post_comment':
        return '$actorName زیر نوشته‌ات دیدگاهی ثبت کرده است.';
      case 'comment_reply':
        return '$actorName به دیدگاهت پاسخ داده است.';
      default:
        return '$actorName یک اعلان برایت ایجاد کرده است.';
    }
  }
}
