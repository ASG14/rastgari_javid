
import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/auth_user.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../notifications/data/notification_repository.dart';
import '../../../notifications/presentation/screens/notifications_screen.dart';
import '../../../posts/models/post.dart';
import '../../../posts/presentation/screens/create_post_screen.dart';
import '../../../posts/presentation/screens/post_feed_screen.dart';
import '../widgets/app_bottom_navigation.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.authRepository,
  });

  final AuthUser user;
  final AuthRepository authRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final NotificationRepository _notificationRepository =
      NotificationRepository();

  int _currentIndex = 0;
  int _feedRefreshVersion = 0;
  int _unreadNotificationCount = 0;
  bool _isLoggingOut = false;
  bool _isLoadingUnreadCount = false;

  @override
  void initState() {
    super.initState();
    _refreshUnreadNotificationCount();
  }

  Future<void> _refreshUnreadNotificationCount() async {
    if (_isLoadingUnreadCount) return;

    _isLoadingUnreadCount = true;

    try {
      final count = await _notificationRepository.getUnreadCount();

      if (!mounted) return;

      setState(() {
        _unreadNotificationCount = count;
      });
    } catch (_) {
      // A badge failure should not prevent the home screen from working.
    } finally {
      _isLoadingUnreadCount = false;
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsScreen(
          repository: _notificationRepository,
        ),
      ),
    );

    if (mounted) {
      await _refreshUnreadNotificationCount();
    }
  }

  Future<void> _logout() async {
    setState(() => _isLoggingOut = true);

    try {
      await widget.authRepository.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => LoginScreen(authRepository: widget.authRepository),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خروج از حساب با خطا مواجه شد: $error')),
      );

      setState(() => _isLoggingOut = false);
    }
  }

  void _handlePostCreated(Post post) {
    setState(() {
      _feedRefreshVersion++;
      _currentIndex = 0;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('نوشته با موفقیت منتشر شد.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildNotificationButton() {
    final colors = Theme.of(context).colorScheme;

    return IconButton(
      tooltip: 'اعلان‌ها',
      onPressed: _openNotifications,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none_rounded, size: 27),
          if (_unreadNotificationCount > 0)
            Positioned(
              top: -5,
              right: -7,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 17,
                  minHeight: 17,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: colors.error,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.surface,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _unreadNotificationCount > 99
                      ? '99+'
                      : '$_unreadNotificationCount',
                  style: TextStyle(
                    color: colors.onError,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['خانه', 'گفتگوها', 'افزودن پست', 'رویدادها', 'پروفایل من'];

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_currentIndex]),
        actions: [
          if (_currentIndex == 0) _buildNotificationButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(
            user: widget.user,
            authRepository: widget.authRepository,
            feedRefreshVersion: _feedRefreshVersion,
          ),
          const _PlaceholderTab(
            icon: Icons.chat_bubble_outline,
            title: 'گفتگوها',
            description: 'گفتگوهای خصوصی در این بخش قرار می‌گیرند.',
          ),
          CreatePostScreen(
            authRepository: widget.authRepository,
            onPostCreated: _handlePostCreated,
          ),
          const _PlaceholderTab(
            icon: Icons.event_outlined,
            title: 'رویدادها',
            description: 'رویدادهای مرتبط در این بخش نمایش داده می‌شوند.',
          ),
          _ProfileTab(
            user: widget.user,
            isLoggingOut: _isLoggingOut,
            onLogout: _logout,
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);

          if (index == 0) {
            _refreshUnreadNotificationCount();
          }
        },
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.user,
    required this.authRepository,
    required this.feedRefreshVersion,
  });

  final AuthUser user;
  final AuthRepository authRepository;
  final int feedRefreshVersion;

  @override
  Widget build(BuildContext context) {
    return PostFeedScreen(
      key: ValueKey(feedRefreshVersion),
      user: user,
      authRepository: authRepository,
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.user,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final AuthUser user;
  final bool isLoggingOut;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 44,
            child: Icon(Icons.person_outline, size: 48),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            user.displayName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text('@${user.username}')),
        if (user.email != null && user.email!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(child: Text(user.email!)),
        ],
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: isLoggingOut ? null : onLogout,
          icon: const Icon(Icons.logout),
          label: Text(isLoggingOut ? 'در حال خروج...' : 'خروج از حساب'),
        ),
      ],
    );
  }
}
