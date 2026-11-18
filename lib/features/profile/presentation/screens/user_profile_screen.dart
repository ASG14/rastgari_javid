import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../posts/data/posts_repository.dart';
import '../../../posts/models/post.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../../data/profile_repository.dart';
import '../../data/user_profile_repository.dart';
import '../widgets/profile_stats.dart';
import '../widgets/profile_tabs.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.currentUserId,
    required this.authRepository,
  });

  final int userId;
  final int currentUserId;
  final AuthRepository authRepository;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  final UserProfileRepository _repository = UserProfileRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final PostsRepository _postsRepository = PostsRepository();

  static const int _pageSize = 20;

  late final TabController _tabController;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _relationship;

  List<Post> _posts = [];
  List<Map<String, dynamic>> _memorialProfiles = [];

  bool _isLoading = true;
  bool _isLoadingPosts = false;
  bool _isLoadingMemorialProfiles = false;
  bool _isLoadingMore = false;
  bool _isUpdatingRelationship = false;
  bool _hasMore = false;

  String? _error;
  String? _postsError;
  String? _memorialProfilesError;
  String? _nextCursor;

  int _postsRequestGeneration = 0;

  bool get _isOwnProfile => widget.userId == widget.currentUserId;

  bool get _isPrivate => _profile?['is_private'] == true;

  bool get _isFollowing => _relationship?['is_following'] == true;

  bool get _hasPendingRequest =>
      _relationship?['has_pending_follow_request'] == true;

  bool get _canViewPosts => _profile?['can_view_posts'] == true;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<String> _readToken() async {
    final token = await widget.authRepository.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('نشست کاربری معتبر نیست. دوباره وارد شوید.');
    }

    return token;
  }

  int _readCount(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _readToken();

      final response = await _repository.getUserProfile(
        userId: widget.userId,
        token: token,
      );

      if (response['status'] == 'blocked') {
        throw Exception('نمایش این پروفایل امکان‌پذیر نیست.');
      }

      if (response['status'] != 'found') {
        throw Exception('پروفایل کاربر دریافت نشد.');
      }

      final profileData = response['profile'];

      if (profileData is! Map) {
        throw const FormatException('اطلاعات پروفایل در پاسخ سرور معتبر نیست.');
      }

      final profile = Map<String, dynamic>.from(profileData);
      final relationshipData = profile['relationship'];

      if (relationshipData is! Map) {
        throw const FormatException(
          'اطلاعات ارتباط کاربر در پاسخ سرور معتبر نیست.',
        );
      }

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _relationship = Map<String, dynamic>.from(relationshipData);
        _isLoading = false;
      });

      if (profile['can_view_posts'] == true) {
        await Future.wait([_loadPosts(), _loadMemorialProfiles()]);
      } else {
        ++_postsRequestGeneration;

        setState(() {
          _posts = [];
          _memorialProfiles = [];
          _hasMore = false;
          _nextCursor = null;
          _postsError = null;
          _memorialProfilesError = null;
          _isLoadingPosts = false;
          _isLoadingMemorialProfiles = false;
          _isLoadingMore = false;
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPosts() async {
    if (!mounted || _isLoadingPosts) return;

    final generation = ++_postsRequestGeneration;

    setState(() {
      _isLoadingPosts = true;
      _postsError = null;
      _nextCursor = null;
    });

    try {
      final token = await _readToken();

      final page = await _postsRepository.getUserPosts(
        userId: widget.userId,
        token: token,
        limit: _pageSize,
      );

      if (!mounted || generation != _postsRequestGeneration) return;

      setState(() {
        _posts = page.posts;
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
        _isLoadingPosts = false;
      });
    } catch (error) {
      if (!mounted || generation != _postsRequestGeneration) return;

      setState(() {
        _postsError = error.toString();
        _isLoadingPosts = false;
      });
    }
  }

  Future<void> _loadMemorialProfiles() async {
    if (!mounted || _isLoadingMemorialProfiles) return;

    setState(() {
      _isLoadingMemorialProfiles = true;
      _memorialProfilesError = null;
    });

    try {
      final token = await _readToken();

      final profiles = await _profileRepository.getUserMemorialProfiles(
        userId: widget.userId,
        token: token,
      );

      if (!mounted) return;

      setState(() {
        _memorialProfiles = profiles;
        _isLoadingMemorialProfiles = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _memorialProfilesError = error.toString();
        _isLoadingMemorialProfiles = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (!mounted ||
        _isLoadingMore ||
        _isLoadingPosts ||
        !_hasMore ||
        _nextCursor == null) {
      return;
    }

    final generation = _postsRequestGeneration;
    final requestedCursor = _nextCursor!;

    setState(() {
      _isLoadingMore = true;
      _postsError = null;
    });

    try {
      final token = await _readToken();

      final page = await _postsRepository.getUserPosts(
        userId: widget.userId,
        token: token,
        limit: _pageSize,
        cursor: requestedCursor,
      );

      if (!mounted || generation != _postsRequestGeneration) return;

      if (page.hasMore && page.nextCursor == requestedCursor) {
        throw const FormatException('نشانگر صفحه بعد تغییر نکرده است.');
      }

      final existingIds = _posts.map((post) => post.id).toSet();
      final newPosts = page.posts.where((post) => existingIds.add(post.id));

      setState(() {
        _posts = [..._posts, ...newPosts];
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _postsRequestGeneration) return;

      setState(() {
        _postsError = error.toString();
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _handleRelationshipAction() async {
    if (_isUpdatingRelationship || _isOwnProfile) return;

    setState(() => _isUpdatingRelationship = true);

    try {
      final token = await _readToken();

      if (_hasPendingRequest) {
        final requestId = await _repository.findOutgoingRequestId(
          targetUserId: widget.userId,
          token: token,
        );

        if (requestId == null) {
          throw Exception(
            'درخواست در انتظار پیدا نشد. صفحه را دوباره بارگذاری کنید.',
          );
        }

        await _repository.cancelFollowRequest(
          requestId: requestId,
          token: token,
        );
      } else if (_isFollowing) {
        final confirmed = await _confirmUnfollow();

        if (!confirmed) return;

        await _repository.unfollowUser(userId: widget.userId, token: token);
      } else {
        await _repository.followUser(userId: widget.userId, token: token);
      }

      await _loadProfile();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('عملیات انجام نشد: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdatingRelationship = false);
      }
    }
  }

  Future<bool> _confirmUnfollow() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('لغو دوستی'),
          content: const Text(
            'آیا مطمئن هستید که می‌خواهید دنبال‌کردن این کاربر را لغو کنید؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('لغو دوستی'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  void _openAuthorProfile(Post post) {
    final authorId = int.tryParse(post.author.id);

    if (authorId == null || authorId < 1) {
      _showMessage('شناسه نویسنده معتبر نیست.');
      return;
    }

    if (authorId == widget.userId) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(
          userId: authorId,
          currentUserId: widget.currentUserId,
          authRepository: widget.authRepository,
        ),
      ),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  Widget _buildRelationshipButton() {
    final colors = Theme.of(context).colorScheme;

    final String label;
    final IconData icon;
    final bool outlined;

    if (_hasPendingRequest) {
      label = 'درخواست ارسال‌شده';
      icon = Icons.schedule_rounded;
      outlined = true;
    } else if (_isFollowing) {
      label = 'لغو دوستی';
      icon = Icons.person_remove_alt_1_rounded;
      outlined = true;
    } else {
      label = 'درخواست دوستی';
      icon = Icons.person_add_alt_1_rounded;
      outlined = false;
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isUpdatingRelationship ? null : _handleRelationshipAction,
        icon: _isUpdatingRelationship
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: 19),
        label: Text(_isUpdatingRelationship ? 'در حال انجام...' : label),
        style: OutlinedButton.styleFrom(
          foregroundColor: outlined ? colors.onSurface : colors.onPrimary,
          backgroundColor: outlined ? null : colors.primary,
          side: BorderSide(color: outlined ? colors.outline : colors.primary),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  Widget _buildStats() {
    final statsData = _profile?['stats'];
    final stats = statsData is Map
        ? Map<String, dynamic>.from(statsData)
        : _profile ?? <String, dynamic>{};

    return ProfileStats(
      postsCount: _readCount(stats['posts_count']),
      followersCount: _readCount(stats['followers_count']),
      followingCount: _readCount(stats['following_count']),
      memorialProfilesCount: _readCount(stats['memorial_profiles_count']),
    );
  }

  Widget _buildLockedContent() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 52,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            'این حساب خصوصی است',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'برای مشاهده نوشته‌ها و محتوای اختصاصی این کاربر، درخواست دوستی ارسال کنید.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostsSection() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (!_canViewPosts) {
      return _buildLockedContent();
    }

    if (_isLoadingPosts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_postsError != null && _posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 10),
            const Text('دریافت نوشته‌ها ناموفق بود.'),
            const SizedBox(height: 12),
            Text(
              _postsError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadPosts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تلاش مجدد'),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 38),
        child: Column(
          children: [
            Icon(
              Icons.article_outlined,
              size: 44,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'هنوز نوشته‌ای منتشر نشده است',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final post in _posts)
          PostCard(
            key: ValueKey(post.id),
            post: post,
            authRepository: widget.authRepository,
            onAuthorTap: () => _openAuthorProfile(post),
          ),
        if (_postsError != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'دریافت نوشته‌های بعدی ناموفق بود: $_postsError',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: colors.error),
            ),
          ),
        if (_hasMore || _isLoadingMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: OutlinedButton(
                onPressed: _isLoadingMore ? null : _loadMorePosts,
                child: _isLoadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('بارگذاری نوشته‌های بیشتر'),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'به پایان نوشته‌ها رسیدید',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMemorialProfilesSection() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (!_canViewPosts) {
      return _buildLockedContent();
    }

    if (_isLoadingMemorialProfiles) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_memorialProfilesError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 10),
            const Text('دریافت عزیزان آسمانی ناموفق بود.'),
            const SizedBox(height: 12),
            Text(
              _memorialProfilesError!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadMemorialProfiles,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تلاش دوباره'),
            ),
          ],
        ),
      );
    }

    if (_memorialProfiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 44,
              color: colors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'هنوز پروفایل یادبودی ثبت نشده است',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _memorialProfiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final memorial = _memorialProfiles[index];

        final name = memorial['full_name']?.toString() ?? 'بدون نام';
        final relationship = memorial['relationship']?.toString();
        final isCreator = memorial['is_creator'] == true;

        return Card(
          elevation: 0,
          color: colors.surfaceContainerLow,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: const Icon(Icons.favorite_rounded),
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

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final displayName = _profile?['display_name']?.toString() ?? 'کاربر';
    final username = _profile?['username']?.toString() ?? '';
    final bio = _profile?['bio']?.toString().trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 39,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
              child: const Icon(Icons.person_rounded, size: 42),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '@$username',
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPrivate
                            ? Icons.lock_outline_rounded
                            : Icons.public_rounded,
                        size: 15,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isPrivate ? 'حساب خصوصی' : 'حساب عمومی',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(bio, style: theme.textTheme.bodyMedium?.copyWith(height: 1.9)),
        ],
        const SizedBox(height: 22),
        _buildStats(),
        if (!_isOwnProfile) ...[
          const SizedBox(height: 22),
          _buildRelationshipButton(),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _profile?['username'] is String
                ? '@${_profile!['username']}'
                : 'پروفایل کاربر',
            textDirection: TextDirection.ltr,
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 44),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadProfile,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('تلاش مجدد'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadProfile,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 24),
                    Divider(color: colors.outlineVariant),
                    const SizedBox(height: 12),
                    ProfileTabs(
                      controller: _tabController,
                      height: 560,
                      tabs: const [
                        Tab(text: 'نوشته‌ها'),
                        Tab(text: 'عزیزان آسمانی'),
                        Tab(text: 'رویدادها'),
                      ],
                      children: [
                        _buildPostsSection(),
                        _buildMemorialProfilesSection(),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'رویدادهای این کاربر در این بخش نمایش داده می‌شوند.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                height: 1.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
