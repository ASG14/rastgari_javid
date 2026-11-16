
import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/auth_user.dart';
import '../../../comments/presentation/screens/post_comments_screen.dart';
import '../../../posts/data/posts_repository.dart';
import '../../../posts/models/post.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../../data/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.authRepository,
    required this.onEditProfile,
  });

  final AuthUser user;
  final AuthRepository authRepository;
  final VoidCallback onEditProfile;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ScrollController _postsScrollController;

  final PostsRepository _postsRepository = PostsRepository();
  final ProfileRepository _profileRepository = ProfileRepository();

  List<Post> _posts = [];
  List<Map<String, dynamic>> _memorialProfiles = [];

  int _followersCount = 0;
  int _followingCount = 0;
  int _postsCount = 0;
  int _memorialProfilesCount = 0;

  bool _isLoadingPosts = true;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = false;
  bool _isLoadingProfileData = true;

  String? _postsError;
  String? _loadMoreError;
  String? _profileDataError;
  String? _nextCursor;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);

    _postsScrollController = ScrollController()
      ..addListener(_handlePostsScroll);

    _loadMyPosts();
    _loadProfileData();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.user.id != widget.user.id) {
      _loadMyPosts();
      _loadProfileData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();

    _postsScrollController
      ..removeListener(_handlePostsScroll)
      ..dispose();

    super.dispose();
  }

  void _handlePostsScroll() {
    if (!_postsScrollController.hasClients ||
        _isLoadingPosts ||
        _isLoadingMorePosts ||
        !_hasMorePosts) {
      return;
    }

    if (_postsScrollController.position.extentAfter < 400) {
      _loadMorePosts();
    }
  }

  Future<String> _requireAccessToken() async {
    final token = await widget.authRepository.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception(
        'نشست کاربری معتبر نیست. لطفاً دوباره وارد شوید.',
      );
    }

    return token;
  }

  Future<void> _refreshProfile() async {
    await Future.wait([
      _loadMyPosts(),
      _loadProfileData(),
    ]);
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;

    setState(() {
      _isLoadingProfileData = true;
      _profileDataError = null;
    });

    try {
      final token = await _requireAccessToken();

      final results = await Future.wait([
        _profileRepository.getUserProfile(
          userId: widget.user.id,
          token: token,
        ),
        _profileRepository.getMyMemorialProfiles(
          token: token,
        ),
      ]);

      final profile = results[0] as Map<String, dynamic>;
      final memorialProfiles =
          results[1] as List<Map<String, dynamic>>;

      if (profile['status'] == 'blocked') {
        throw Exception('دسترسی به اطلاعات این حساب امکان‌پذیر نیست.');
      }

      if (!mounted) return;

      setState(() {
        _followersCount = _readCount(profile['followers_count']);
        _followingCount = _readCount(profile['following_count']);
        _postsCount = _readCount(profile['posts_count']);

        _memorialProfiles = memorialProfiles;

        _memorialProfilesCount = _readCount(
          profile['memorial_profiles_count'],
        );

        // تعداد فهرست دریافت‌شده مرجع جایگزین در صورت نبود مقدار آماری است.
        if (profile['memorial_profiles_count'] == null) {
          _memorialProfilesCount = memorialProfiles.length;
        }

        _isLoadingProfileData = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _profileDataError = error.toString();
        _isLoadingProfileData = false;
      });
    }
  }

  int _readCount(dynamic value) {
    if (value is num) return value.toInt();
    return 0;
  }

  Future<void> _loadMyPosts() async {
    if (!mounted) return;

    setState(() {
      _isLoadingPosts = true;
      _isLoadingMorePosts = false;
      _hasMorePosts = false;
      _postsError = null;
      _loadMoreError = null;
      _nextCursor = null;
      _posts = [];
    });

    try {
      final token = await _requireAccessToken();

      final page = await _postsRepository.getOwnPosts(
        token: token,
        limit: 20,
      );

      if (!mounted) return;

      setState(() {
        _posts = page.posts;
        _hasMorePosts = page.hasMore;
        _nextCursor = page.nextCursor;
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

  Future<void> _loadMorePosts() async {
    if (_isLoadingPosts ||
        _isLoadingMorePosts ||
        !_hasMorePosts ||
        _nextCursor == null) {
      return;
    }

    setState(() {
      _isLoadingMorePosts = true;
      _loadMoreError = null;
    });

    try {
      final token = await _requireAccessToken();

      final page = await _postsRepository.getOwnPosts(
        token: token,
        limit: 20,
        cursor: _nextCursor,
      );

      if (!mounted) return;

      setState(() {
        _posts = [..._posts, ...page.posts];
        _hasMorePosts = page.hasMore;
        _nextCursor = page.nextCursor;
        _isLoadingMorePosts = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadMoreError = error.toString();
        _isLoadingMorePosts = false;
      });
    }
  }

  Future<void> _handleLikeChanged(
    Post post,
    bool isLiked,
  ) async {
    final token = await _requireAccessToken();

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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: RefreshIndicator(
        onRefresh: _refreshProfile,
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
                  _buildMemorialProfilesTab(context),
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
          const SizedBox(height: 10),
          _buildPrivacyStatus(context),
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
          const SizedBox(height: 20),
          _buildProfileStats(context),
          const SizedBox(height: 18),
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStats(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoadingProfileData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_profileDataError != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadProfileData,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('دریافت آمار ناموفق بود؛ تلاش دوباره'),
        ),
      );
    }

    final stats = [
      ('پست‌ها', _postsCount),
      ('دنبال‌کننده', _followersCount),
      ('دنبال‌شونده', _followingCount),
      ('عزیزان آسمانی', _memorialProfilesCount),
    ];

    return Row(
      children: [
        for (final stat in stats)
          Expanded(
            child: Column(
              children: [
                Text(
                  stat.$2.toString(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stat.$1,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPrivacyStatus(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isPrivate = widget.user.isPrivate;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPrivate
                ? Icons.lock_outline_rounded
                : Icons.public_rounded,
            size: 15,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            isPrivate ? 'حساب خصوصی' : 'حساب عمومی',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
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
        message: widget.user.isPrivate
            ? 'پست‌هایی که در حساب خصوصی خود منتشر می‌کنید، در این بخش نمایش داده می‌شوند.'
            : 'پست‌های شما پس از انتشار در این بخش نمایش داده می‌شوند.',
      );
    }

    return ListView.builder(
      controller: _postsScrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount:
          _posts.length + (_hasMorePosts || _loadMoreError != null ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _posts.length) {
          return _buildLoadMoreFooter(context);
        }

        final post = _posts[index];

        return PostCard(
          key: ValueKey(post.id),
          post: post,
          onLikeChanged: (isLiked) {
            return _handleLikeChanged(post, isLiked);
          },
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

  Widget _buildMemorialProfilesTab(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (_isLoadingProfileData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_profileDataError != null) {
      return _buildMessageState(
        context,
        icon: Icons.cloud_off_outlined,
        title: 'دریافت اطلاعات ناموفق بود',
        message: _profileDataError!,
        action: TextButton(
          onPressed: _loadProfileData,
          child: const Text('تلاش دوباره'),
        ),
      );
    }

    if (_memorialProfiles.isEmpty) {
      return _buildMessageState(
        context,
        icon: Icons.favorite_border_rounded,
        title: 'هنوز پروفایل یادبودی ندارید',
        message:
            'پروفایل عزیزان آسمانی که ساخته‌اید یا دنبال می‌کنید، اینجا نمایش داده می‌شود.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _memorialProfiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final profile = _memorialProfiles[index];

        final name =
            profile['full_name']?.toString() ?? 'بدون نام';

        final relationship =
            profile['relationship']?.toString();

        final isCreator = profile['is_creator'] == true;

        return Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colors.primaryContainer,
              child: Icon(
                Icons.favorite_rounded,
                color: colors.onPrimaryContainer,
              ),
            ),
            title: Text(
              name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              isCreator
                  ? 'سازنده پروفایل یادبود'
                  : 'نسبت: ${relationship ?? 'مشخص نشده'}',
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreFooter(BuildContext context) {
    if (_isLoadingMorePosts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(
              'دریافت ادامه پست‌ها ناموفق بود.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton.icon(
              onPressed: _loadMorePosts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تلاش دوباره'),
            ),
          ],
        ),
      );
    }

    return const SizedBox(height: 20);
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
            Icon(
              icon,
              size: 44,
              color: colors.primary,
            ),
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
