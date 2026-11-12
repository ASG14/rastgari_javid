import 'package:flutter/material.dart';

import 'widgets/app_bottom_navigation.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/models/auth_user.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/events/presentation/screens/events_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/messages/presentation/screens/messages_screen.dart';
import '../../features/notifications/data/notification_repository.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/posts/models/post.dart';
import '../../features/posts/presentation/screens/create_post_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
    required this.user,
    required this.authRepository,
  });

  final AuthUser user;
  final AuthRepository authRepository;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  final NotificationRepository _notificationRepository =
      NotificationRepository();

  late AuthUser _user;

  int _currentIndex = 0;
  int _feedRefreshVersion = 0;
  int _unreadNotificationCount = 0;

  bool _isLoggingOut = false;
  bool _isLoadingUnreadCount = false;

  static const List<String> _titles = [
    'خانه',
    'گفتگوها',
    'افزودن پست',
    'رویدادها',
    'پروفایل من',
  ];

  @override
  void initState() {
    super.initState();
    _user = widget.user;
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
      // خطای دریافت اعلان‌ها نباید مانع استفاده از برنامه شود.
    } finally {
      _isLoadingUnreadCount = false;
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            NotificationsScreen(repository: _notificationRepository),
      ),
    );

    if (mounted) {
      await _refreshUnreadNotificationCount();
    }
  }

  Future<void> _openEditProfile() async {
    final updatedUser = await Navigator.of(context).push<AuthUser>(
      MaterialPageRoute<AuthUser>(
        builder: (_) => EditProfileScreen(
          user: _user,
          authRepository: widget.authRepository,
        ),
      ),
    );

    if (!mounted || updatedUser == null) return;

    setState(() {
      _user = updatedUser;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('پروفایل با موفقیت به‌روزرسانی شد.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await widget.authRepository.logout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => LoginScreen(authRepository: widget.authRepository),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خروج از حساب با خطا مواجه شد: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _isLoggingOut = false;
      });
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
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.error,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.surface, width: 1.5),
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
    final pages = <Widget>[
      HomeScreen(
        user: _user,
        authRepository: widget.authRepository,
        feedRefreshVersion: _feedRefreshVersion,
      ),
      const MessagesScreen(),
      CreatePostScreen(
        authRepository: widget.authRepository,
        onPostCreated: _handlePostCreated,
      ),
      const EventsScreen(),
      ProfileScreen(
        user: _user,
        authRepository: widget.authRepository,
        isLoggingOut: _isLoggingOut,
        onEditProfile: _openEditProfile,
        onLogout: _logout,
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[_currentIndex]),
          actions: [
            if (_currentIndex == 0) _buildNotificationButton(),
            const SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(index: _currentIndex, children: pages),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });

            if (index == 0) {
              _refreshUnreadNotificationCount();
            }
          },
        ),
      ),
    );
  }
}
