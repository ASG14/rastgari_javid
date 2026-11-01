import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/auth_user.dart';
import '../../data/posts_repository.dart';
import '../../models/post.dart';
import '../widgets/post_card.dart';
import '../../../comments/presentation/screens/post_comments_screen.dart';

class PostFeedScreen extends StatefulWidget {
  const PostFeedScreen({
    super.key,
    required this.user,
    required this.authRepository,
  });

  final AuthUser user;
  final AuthRepository authRepository;

  @override
  State<PostFeedScreen> createState() => _PostFeedScreenState();
}

class _PostFeedScreenState extends State<PostFeedScreen> {
  final PostsRepository _postsRepository = PostsRepository();

  List<Post> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await widget.authRepository.readAccessToken();
      final posts = await _postsRepository.getPublicPosts(token: token);

      if (!mounted) return;

      setState(() {
        _posts = posts;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLikeChanged(Post post, bool isLiked) async {
    final token = await widget.authRepository.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('برای ثبت همدلی باید وارد حساب کاربری شوید.');
    }

    final result = await _postsRepository.setPostLike(
      postId: post.id,
      isLiked: isLiked,
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

    if (serverPostId != null && serverPostId != post.id) {
      throw const FormatException(
        'شناسه پست در پاسخ سرور با پست انتخاب‌شده مطابقت ندارد.',
      );
    }

    if (!mounted) return;

    setState(() {
      _posts = _posts.map((item) {
        if (item.id != post.id) return item;

        return item.copyWith(
          isLiked: serverIsLiked,
          likeCount: serverLikeCount.toInt(),
        );
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _loadPosts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _buildWelcomeCard(context),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  'تازه‌ترین نوشته‌ها',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.auto_awesome_outlined,
                  color: colors.primary,
                  size: 21,
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 56),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildErrorState(context)
            else if (_posts.isEmpty)
              _buildEmptyState(context)
            else
              for (final post in _posts)
                PostCard(
                  key: ValueKey(post.id),
                  post: post,
                  onLikeChanged: (isLiked) => _handleLikeChanged(post, isLiked),
                  onCommentsTap: () async {
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute<bool>(
                        builder: (context) => PostCommentsScreen(
                          post: post,
                          authRepository: widget.authRepository,
                        ),
                      ),
                    );

                    if (mounted) {
                      await _loadPosts();
                    }
                  },
                  onShareTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'اشتراک‌گذاری در مرحله بعد اضافه می‌شود.',
                        ),
                      ),
                    );
                  },
                ),
            if (!_isLoading && _errorMessage == null && _posts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'پایان نوشته‌های دریافت‌شده',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [colors.primaryContainer, colors.surfaceContainerHighest],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.spa_outlined,
                  color: colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'رستگاری جاوید',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'فضایی برای شنیدن و همراهی',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'سلام ${widget.user.displayName}،',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'اینجا جایی است برای خاطره‌ها، تجربه‌ها و همراهی با یکدیگر.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.9,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
      child: Column(
        children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: colors.error),
          const SizedBox(height: 12),
          Text(
            'دریافت نوشته‌ها ناموفق بود',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'خطای نامشخص',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loadPosts,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.forum_outlined, size: 48, color: colors.primary),
          const SizedBox(height: 12),
          Text(
            'هنوز نوشته‌ای منتشر نشده است',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'وقتی نوشته‌های عمومی منتشر شوند، اینجا نمایش داده می‌شوند.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
