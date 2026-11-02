import 'package:flutter/material.dart';

import '../../models/post.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    this.onLikeChanged,
    this.onCommentsTap,
    this.onShareTap,
  });

  final Post post;
  final Future<void> Function(bool isLiked)? onLikeChanged;
  final VoidCallback? onCommentsTap;
  final VoidCallback? onShareTap;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isUpdatingLike = false;

  Future<void> _toggleLike() async {
    if (_isUpdatingLike || widget.onLikeChanged == null) return;

    setState(() => _isUpdatingLike = true);

    try {
      await widget.onLikeChanged!(!widget.post.isLiked);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تغییر وضعیت همدلی ناموفق بود: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingLike = false);
      }
    }
  }

  String _formatTime(DateTime date) {
    final difference = DateTime.now().difference(date);

    if (difference.inSeconds < 60) return 'همین حالا';
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    }
    if (difference.inDays == 1) return 'دیروز';
    if (difference.inDays < 7) return '${difference.inDays} روز پیش';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final author = widget.post.author;
    final isLiked = widget.post.isLiked;
    final likeCount = widget.post.likeCount;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 22,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 17, 16, 12),
            child: Row(
              children: [
                _AuthorAvatar(
                  displayName: author.displayName,
                  avatarUrl: author.avatarUrl,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              author.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                          if (author.isVerified) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.verified_rounded,
                              size: 16,
                              color: colors.primary,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '@${author.username} · ${_formatTime(widget.post.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'گزینه‌های بیشتر',
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz_rounded),
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Text(
              widget.post.content,
              textAlign: TextAlign.start,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.95,
                fontSize: 14.5,
                color: colors.onSurface,
              ),
            ),
          ),
          if (widget.post.mediaUrl != null && widget.post.mediaUrl!.isNotEmpty)
            _PostMedia(url: widget.post.mediaUrl!),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                if (likeCount > 0) ...[
                  Icon(
                    Icons.favorite_rounded,
                    size: 16,
                    color: isLiked ? colors.error : colors.primary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$likeCount',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                if (widget.post.commentCount > 0)
                  Text(
                    '${widget.post.commentCount} گفتگو',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: colors.outlineVariant.withValues(alpha: 0.65),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 7),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: _isUpdatingLike
                        ? Icons.hourglass_top_rounded
                        : isLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: _isUpdatingLike ? 'در حال ثبت...' : 'همدلی',
                    color: isLiked ? colors.error : null,
                    onTap: _isUpdatingLike ? null : _toggleLike,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.mode_comment_outlined,
                    label: 'گفتگو',
                    onTap: widget.onCommentsTap,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.ios_share_rounded,
                    label: 'اشتراک',
                    onTap: widget.onShareTap,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.displayName, this.avatarUrl});

  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: colors.primaryContainer,
        backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
        child: !hasAvatar
            ? Text(
                displayName.isNotEmpty ? displayName[0] : '؟',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: colors.onPrimaryContainer,
                ),
              )
            : null,
      ),
    );
  }
}

class _PostMedia extends StatelessWidget {
  const _PostMedia({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined, size: 42),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;

          return Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = color ?? colors.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
