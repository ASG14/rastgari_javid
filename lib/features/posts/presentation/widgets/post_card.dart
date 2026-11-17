import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../comments/data/comments_repository.dart';
import '../../../comments/presentation/screens/post_comments_screen.dart';
import '../../data/posts_repository.dart';
import '../../models/post.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.authRepository,
    this.onAuthorTap,
  });

  final Post post;
  final AuthRepository authRepository;

  /// تنها مسئولیت واگذارشده به صفحه والد، مسیریابی به پروفایل نویسنده است.
  final VoidCallback? onAuthorTap;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final PostsRepository _postsRepository = PostsRepository();
  final CommentsRepository _commentsRepository = CommentsRepository();

  late Post _post;

  bool _isUpdatingLike = false;
  bool _isOpeningComments = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // اگر کارت با پست دیگری جایگزین شد، وضعیت داخلی نیز باید عوض شود.
    // تغییرات یک پست یکسان از طرف والد نباید وضعیت محلی تعاملات را بازنویسی کند.
    if (oldWidget.post.id != widget.post.id) {
      _post = widget.post;
    }
  }

  Future<String> _requireAccessToken() async {
    final token = await widget.authRepository.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('برای انجام این کار ابتدا وارد حساب کاربری شوید.');
    }

    return token;
  }

  Future<void> _toggleLike() async {
    if (_isUpdatingLike) return;

    setState(() => _isUpdatingLike = true);

    try {
      final token = await _requireAccessToken();
      final nextLikedState = !_post.isLiked;

      final result = await _postsRepository.setPostLike(
        postId: _post.id,
        isLiked: nextLikedState,
        token: token,
      );

      final serverPostId = result['post_id']?.toString();
      final serverIsLiked = result['is_liked'];
      final serverLikeCount = result['likes_count'];

      if (serverIsLiked is! bool || serverLikeCount is! num) {
        throw const FormatException(
          'پاسخ سرور برای به‌روزرسانی همدلی معتبر نیست.',
        );
      }

      if (serverPostId != null && serverPostId != _post.id) {
        throw const FormatException(
          'شناسه پست در پاسخ سرور با پست انتخاب‌شده مطابقت ندارد.',
        );
      }

      if (!mounted) return;

      setState(() {
        _post = _post.copyWith(
          isLiked: serverIsLiked,
          likeCount: serverLikeCount.toInt(),
        );
      });
    } catch (error) {
      if (!mounted) return;
      _showMessage('تغییر وضعیت همدلی ناموفق بود: ${_readableError(error)}');
    } finally {
      if (mounted) {
        setState(() => _isUpdatingLike = false);
      }
    }
  }

  Future<void> _openComments() async {
    if (_isOpeningComments) return;

    setState(() => _isOpeningComments = true);

    try {
      final createdComment = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => PostCommentsScreen(
            post: _post,
            authRepository: widget.authRepository,
          ),
        ),
      );

      if (!mounted) return;

      // تعداد گفتگوها از خود API دریافت می‌شود تا شمارنده مستقل از صفحه والد باشد.
      try {
        final token = await _requireAccessToken();
        final comments = await _commentsRepository.getPostComments(
          postId: _post.id,
          token: token,
        );

        if (!mounted) return;

        setState(() {
          _post = _post.copyWith(commentCount: comments.length);
        });
      } catch (_) {
        // اگر دریافت مجدد فهرست ممکن نبود، در صورت ثبت دیدگاه جدید
        // حداقل شمارنده را به اندازه یک واحد به‌روزرسانی می‌کنیم.
        if (createdComment == true && mounted) {
          setState(() {
            _post = _post.copyWith(commentCount: _post.commentCount + 1);
          });
        }
      }
    } catch (error) {
      if (!mounted) return;
      _showMessage('بازکردن گفتگوها ناموفق بود: ${_readableError(error)}');
    } finally {
      if (mounted) {
        setState(() => _isOpeningComments = false);
      }
    }
  }

  Future<void> _sharePost() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);

    try {
      final author = _post.author;
      final shareText =
          '${author.displayName} (@${author.username})\n\n${_post.content}';

      await Clipboard.setData(ClipboardData(text: shareText));

      if (!mounted) return;
      _showMessage('متن نوشته کپی شد و می‌توانید آن را به اشتراک بگذارید.');
    } catch (error) {
      if (!mounted) return;
      _showMessage('کپی نوشته ناموفق بود: ${_readableError(error)}');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  String _readableError(Object error) {
    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
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
    if (difference.inDays < 7) {
      return '${difference.inDays} روز پیش';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Widget _buildAuthor(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final author = _post.author;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onAuthorTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
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
                      '@${author.username} · ${_formatTime(_post.createdAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isLiked = _post.isLiked;
    final likeCount = _post.likeCount;
    final commentCount = _post.commentCount;

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
                Expanded(child: _buildAuthor(context)),
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
              _post.content,
              textAlign: TextAlign.start,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.95,
                fontSize: 14.5,
                color: colors.onSurface,
              ),
            ),
          ),
          if (_post.mediaUrl != null && _post.mediaUrl!.isNotEmpty)
            _PostMedia(url: _post.mediaUrl!),
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
                if (commentCount > 0)
                  Text(
                    '$commentCount گفتگو',
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
                    icon: _isOpeningComments
                        ? Icons.hourglass_top_rounded
                        : Icons.mode_comment_outlined,
                    label: _isOpeningComments ? 'در حال بارگذاری...' : 'گفتگو',
                    onTap: _isOpeningComments ? null : _openComments,
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: _isSharing
                        ? Icons.hourglass_top_rounded
                        : Icons.ios_share_rounded,
                    label: _isSharing ? 'در حال آماده‌سازی...' : 'اشتراک',
                    onTap: _isSharing ? null : _sharePost,
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
