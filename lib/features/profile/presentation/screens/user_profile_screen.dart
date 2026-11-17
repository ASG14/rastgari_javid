import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../posts/data/posts_repository.dart';
import '../../../posts/models/post.dart';
import '../../../posts/presentation/widgets/post_card.dart';
import '../../data/user_profile_repository.dart';

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

class _UserProfileScreenState extends State<UserProfileScreen> {
  final UserProfileRepository _repository = UserProfileRepository();
  final PostsRepository _postsRepository = PostsRepository();

  static const int _pageSize = 20;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _relationship;

  List<Post> _posts = [];

  bool _isLoading = true;
  bool _isLoadingPosts = false;
  bool _isLoadingMore = false;
  bool _isUpdatingRelationship = false;
  bool _hasMore = false;

  String? _error;
  String? _postsError;
  String? _nextCursor;

  bool get _isOwnProfile => widget.userId == widget.currentUserId;

  bool get _isPrivate => _profile?['is_private'] == true;

  bool get _isFollowing => _relationship?['is_following'] == true;

  bool get _hasPendingRequest =>
      _relationship?['has_pending_follow_request'] == true;

  bool get _canViewPosts => _profile?['can_view_posts'] == true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<String> _readToken() async {
    final token = await widget.authRepository.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('نشست کاربری معتبر نیست. دوباره وارد شوید.');
    }

    return token;
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
        await _loadPosts();
      } else {
        setState(() {
          _posts = [];
          _hasMore = false;
          _nextCursor = null;
          _postsError = null;
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

      if (!mounted) return;

      setState(() {
        _posts = page.posts;
        _hasMore = page.hasMore;
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
    if (!mounted || _isLoadingMore || !_hasMore || _nextCursor == null) {
      return;
    }

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
        cursor: _nextCursor,
      );

      if (!mounted) return;

      final existingIds = _posts.map((post) => post.id).toSet();
      final newPosts = page.posts.where((post) => existingIds.add(post.id));

      setState(() {
        _posts = [..._posts, ...newPosts];
        _hasMore = page.hasMore;
        _nextCursor = page.nextCursor;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _postsError = error.toString();
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _handleLikeChanged(Post post, bool isLiked) async {
    final token = await _readToken();

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

  int _readCount(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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
    final theme = Theme.of(context);

    final stats = [
      ('پست‌ها', _readCount(_profile?['posts_count'])),
      ('دنبال‌کننده', _readCount(_profile?['followers_count'])),
      ('دنبال‌شونده', _readCount(_profile?['following_count'])),
      ('عزیزان آسمانی', _readCount(_profile?['memorial_profiles_count'])),
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
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  stat.$1,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
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
            onAuthorTap: () {
              final authorId = int.tryParse(post.author.id);

              if (authorId == null ||
                  authorId < 1 ||
                  authorId == widget.userId) {
                return;
              }

              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => UserProfileScreen(
                    userId: authorId,
                    currentUserId: widget.currentUserId,
                    authRepository: widget.authRepository,
                  ),
                ),
              );
            },
            onLikeChanged: (isLiked) {
              return _handleLikeChanged(post, isLiked);
            },
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
                                _profile?['display_name']?.toString() ??
                                    'کاربر',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '@${_profile?['username'] ?? ''}',
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
                    if ((_profile?['bio'] as String?)?.trim().isNotEmpty ??
                        false) ...[
                      const SizedBox(height: 18),
                      Text(
                        _profile!['bio'] as String,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.9,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _buildStats(),
                    if (!_isOwnProfile) ...[
                      const SizedBox(height: 22),
                      _buildRelationshipButton(),
                    ],
                    const SizedBox(height: 24),
                    Divider(color: colors.outlineVariant),
                    const SizedBox(height: 12),
                    Text(
                      'نوشته‌ها',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildPostsSection(),
                  ],
                ),
              ),
      ),
    );
  }
}
