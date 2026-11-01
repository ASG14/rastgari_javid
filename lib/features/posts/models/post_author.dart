class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.displayName,
    required this.username,
    this.avatarUrl,
    this.isVerified = false,
  });

  final String id;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final bool isVerified;

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final displayName = json['display_name'];
    final username = json['username'];

    return PostAuthor(
      id: id.toString(),
      displayName: displayName is String ? displayName : 'کاربر',
      username: username is String ? username : 'unknown',
      // سرور فعلاً کلید ذخیره‌سازی تصویر را می‌دهد، نه URL مستقیم.
      // بنابراین آن را به عنوان URL تصویر استفاده نمی‌کنیم.
      avatarUrl: null,
      isVerified: json['is_verified'] == true,
    );
  }
}
