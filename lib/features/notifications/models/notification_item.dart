class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.postId,
    required this.createdAt,
    required this.isRead,
    this.commentId,
    this.readAt,
    this.actorId,
    this.actorUsername,
    this.actorDisplayName,
    this.contentPreview,
  });

  final String id;
  final String type;
  final int postId;
  final int? commentId;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isRead;
  final int? actorId;
  final String? actorUsername;
  final String? actorDisplayName;
  final String? contentPreview;

  String get actorName {
    final displayName = actorDisplayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final username = actorUsername?.trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }

    return 'یک کاربر';
  }

  String get message {
    switch (type) {
      case 'post_like':
        return '$actorName با پست شما همدلی کرد.';
      case 'post_comment':
        return '$actorName برای پست شما دیدگاهی نوشت.';
      case 'comment_reply':
        return '$actorName به دیدگاه شما پاسخ داد.';
      default:
        return '$actorName اعلان جدیدی برای شما فرستاد.';
    }
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final actorValue = json['actor'];
    final actor = actorValue is Map
        ? Map<String, dynamic>.from(actorValue)
        : <String, dynamic>{};

    final id = _stringValue(json['id']);
    final type = _stringValue(json['type'] ?? json['notification_type']);

    final postId = _intValue(json['post_id']);
    final createdAt = DateTime.tryParse(_stringValue(json['created_at']));

    if (id.isEmpty) {
      throw const FormatException('شناسه اعلان در پاسخ سرور وجود ندارد.');
    }

    if (type.isEmpty) {
      throw const FormatException('نوع اعلان در پاسخ سرور وجود ندارد.');
    }

    if (postId == null) {
      throw const FormatException('شناسه پست در پاسخ اعلان معتبر نیست.');
    }

    if (createdAt == null) {
      throw const FormatException('زمان ایجاد اعلان در پاسخ سرور معتبر نیست.');
    }

    final readAtValue = json['read_at'];
    final readAt = readAtValue == null
        ? null
        : DateTime.tryParse(_stringValue(readAtValue));

    final actorId = _intValue(actor['id'] ?? json['actor_id']);

    final actorUsername = _nullableString(
      actor['username'] ?? json['actor_username'],
    );

    final actorDisplayName = _nullableString(
      actor['display_name'] ?? json['actor_display_name'],
    );

    return NotificationItem(
      id: id,
      type: type,
      postId: postId,
      commentId: _intValue(json['comment_id']),
      createdAt: createdAt,
      readAt: readAt,
      isRead: _boolValue(json['is_read']) || readAt != null,
      actorId: actorId,
      actorUsername: actorUsername,
      actorDisplayName: actorDisplayName,
      contentPreview: _nullableString(json['content_preview']),
    );
  }

  static String _stringValue(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static String? _nullableString(dynamic value) {
    if (value == null) return null;
    final result = value.toString();
    return result.isEmpty ? null : result;
  }

  static int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }
}
