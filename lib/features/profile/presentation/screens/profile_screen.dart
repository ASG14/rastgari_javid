
import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/auth_user.dart';
import '../../../posts/data/posts_repository.dart';
import '../../../posts/models/post.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../../../comments/presentation/screens/post_comments_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.authRepository,
    required this.isLoggingOut,
    required this.onEditProfile,
    required this.onLogout,
  });

  final AuthUser user;
  final AuthRepository authRepository;
  final bool isLoggingOut;
  final VoidCallback onEditProfile;
  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final PostsRepository _postsRepository = PostsRepository();

  List<Post> _posts = [];
  bool _isLoadingPosts = true;
  String? _postsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMyPosts();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.user.id != widget.user.id) {
      _loadMyPosts();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyPosts() async {
    setState(() {
      _isLoadingPosts = true;
      _postsError = null;
    });

    try {
      final token = await widget.authRepository.readAccessToken();
      final allPosts = await _postsRepository.getPublicPosts(
        token: token,
      );

      if (!mounted) return;

      final myPosts = allPosts
          .where((post) => post.author.id == widget.user.id.toString())
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      setState(() {
        _posts = myPosts;
        _isLoadingPosts = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _postsError = error.toString();
        _isLoadingPosts = false;
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

    final serverIsLiked = result['is_liked'];
    final serverLikeCount = result['likes_count'];

    if (serverIsLiked is! bool || serverLikeCount is! num) {
      throw const FormatException(
        'پاسخ سرور برای به‌روزرسانی همدلی معتبر نیست.',
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _loadMyPosts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            _buildProfileHeader(context),
            const SizedBox(height: 12),
            _buildTabs(context),
            SizedBox(
              height: 520,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPostsTab(context),
                  _buildUnavailableTab(
                    context,
                    icon: Icons.favorite_border_rounded,
                    title: 'عزیزان من',
                    message:
                        'پروفایل‌های یادبود مرتبط با حساب شما در این بخش نمایش داده می‌شوند.',
                  ),
                  _buildUnavailableTab(
                    context,
                    icon: Icons.event_note_rounded,
                    title: 'رویدادهای من',
                    message:
                        'رویدادهای متعلق به حساب شما در این بخش نمایش داده می‌شوند.',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: OutlinedButton.icon(
                onPressed:
                    widget.isLoggingOut ? null : widget.onLogout,
                icon: widget.isLoggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.logout_rounded),
                label: Text(
                  widget.isLoggingOut
                      ? 'در حال خروج...'
                      : 'خروج از حساب',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(
                    color: theme.colorScheme.error
                        .withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final bio = widget.user.bio?.trim();
    final hasBio = bio != null && bio.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: colors.primaryContainer,
                foregroundColor: colors.onPrimaryContainer,
                child: const Icon(
                  Icons.person_rounded,
                  size: 38,
                ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: widget.onEditProfile,
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                ),
                child: const Text('ویرایش پروفایل'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.user.displayName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '@${widget.user.username}',
            textDirection: TextDirection.ltr,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasBio
                ? bio
                : 'هنوز بیوگرافی‌ای برای پروفایل نوشته نشده است.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.8,
              color: hasBio
                  ? colors.onSurface
                  : colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TabBar(
      controller: _tabController,
      isScrollable: false,
      labelColor: colors.primary,
      unselectedLabelColor: colors.onSurfaceVariant,
      indicatorColor: colors.primary,
      indicatorWeight: 3,
      labelStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      tabs: const [
        Tab(text: 'پست‌ها'),
        Tab(text: 'عزیزان من'),
        Tab(text: 'رویدادهای من'),
      ],
    );
  }

  Widget _buildPostsTab(BuildContext context) {
    if (_isLoadingPosts) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_postsError != null) {
      return _buildMessageState(
        context,
        icon: Icons.cloud_off_outlined,
        title: 'دریافت پست‌ها ناموفق بود',
        message: _postsError!,
        action: TextButton.icon(
          onPressed: _loadMyPosts,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('تلاش مجدد'),
        ),
      );
    }

    if (_posts.isEmpty) {
      return _buildMessageState(
        context,
        icon: Icons.post_add_rounded,
        title: 'هنوز پستی منتشر نکرده‌اید',
        message: 'پست‌های عمومی شما پس از انتشار در این بخش نمایش داده می‌شوند.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];

        return PostCard(
          key: ValueKey(post.id),
          post: post,
          onLikeChanged: (isLiked) =>
              _handleLikeChanged(post, isLiked),
          onCommentsTap: () async {
            await Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (_) => PostCommentsScreen(
                  post: post,
                  authRepository: widget.authRepository,
                ),
              ),
            );

            if (mounted) {
              await _loadMyPosts();
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
        );
      },
    );
  }

  Widget _buildUnavailableTab(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return _buildMessageState(
      context,
      icon: icon,
      title: title,
      message: message,
    );
  }

  Widget _buildMessageState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    Widget? action,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: colors.primary),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.8,
                color: colors.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 12),
              action,
            ],
          ],
        ),
      ),
    );
  }
}
