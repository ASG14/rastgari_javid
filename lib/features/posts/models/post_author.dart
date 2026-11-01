
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
}
