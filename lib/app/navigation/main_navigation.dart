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
import '../../features/posts/presentation/screens/create_content_screen.dart';
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
  int _profileRefreshVersion = 0;
  int _unreadNotificationCount = 0;

  bool _isLoggingOut = false;
  bool _isLoadingUnreadCount = false;

  static const List<String> _titles = [
    'خانه',
    'گفتگوها',
    'افزودن',
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

  void _handleMemorialProfileCreated() {
    setState(() {
      _profileRefreshVersion++;
      _currentIndex = 4;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('پروفایل عزیز آسمانی با موفقیت ثبت شد.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleDestinationSelected(int index) {
    setState(() {
      _currentIndex = index;

      if (index == 4) {
        _profileRefreshVersion++;
      }
    });

    if (index == 0) {
      _refreshUnreadNotificationCount();
    }
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

  Widget _buildProfileMenuButton() {
    return Builder(
      builder: (buttonContext) {
        return IconButton(
          tooltip: 'منوی پروفایل',
          onPressed: () {
            Scaffold.of(buttonContext).openDrawer();
          },
          icon: const Icon(Icons.menu_rounded),
        );
      },
    );
  }

  Widget _buildProfileDrawer() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: colors.primaryContainer,
                    child: Icon(
                      Icons.person_rounded,
                      size: 34,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _user.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '@${_user.username}',
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('ویرایش پروفایل'),
              onTap: () {
                Navigator.of(context).pop();
                _openEditProfile();
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              enabled: !_isLoggingOut,
              leading: _isLoggingOut
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.logout_rounded, color: colors.error),
              title: Text(
                _isLoggingOut ? 'در حال خروج...' : 'خروج از حساب',
                style: TextStyle(color: colors.error),
              ),
              onTap: _isLoggingOut
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _logout();
                    },
            ),
            const SizedBox(height: 12),
          ],
        ),
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
      CreateContentScreen(
        authRepository: widget.authRepository,
        onPostCreated: _handlePostCreated,
        onMemorialProfileCreated: _handleMemorialProfileCreated,
      ),
      const EventsScreen(),
      ProfileScreen(
        user: _user,
        authRepository: widget.authRepository,
        onEditProfile: _openEditProfile,
        refreshVersion: _profileRefreshVersion,
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        drawer: _currentIndex == 4 ? _buildProfileDrawer() : null,
        appBar: AppBar(
          title: Text(_titles[_currentIndex]),
          actions: [
            if (_currentIndex == 0) _buildNotificationButton(),
            if (_currentIndex == 4) _buildProfileMenuButton(),
            const SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(index: _currentIndex, children: pages),
        bottomNavigationBar: AppBottomNavigation(
          currentIndex: _currentIndex,
          onDestinationSelected: _handleDestinationSelected,
        ),
      ),
    );
  }
}
