import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
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

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _relationship;

  bool _isLoading = true;
  bool _isUpdatingRelationship = false;

  String? _error;

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
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRelationshipAction() async {
    if (_isUpdatingRelationship || _isOwnProfile) return;

    final token = await _readToken();

    setState(() => _isUpdatingRelationship = true);

    try {
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

    return Center(
      child: Padding(
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
      ),
    );
  }

  Widget _buildPostsPlaceholder() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.article_outlined, size: 46, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              'نوشته‌های کاربر',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'نمایش نوشته‌های این کاربر در مرحله اتصال فهرست پست‌های پروفایل فعال می‌شود.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.8,
              ),
            ),
          ],
        ),
      ),
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
                    if (!_canViewPosts)
                      SizedBox(height: 300, child: _buildLockedContent())
                    else
                      SizedBox(height: 300, child: _buildPostsPlaceholder()),
                  ],
                ),
              ),
      ),
    );
  }
}
