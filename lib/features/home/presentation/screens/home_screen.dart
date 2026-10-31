import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/auth_user.dart';
import '../../../auth/presentation/screens/login_screen.dart';
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
  int _currentIndex = 0;
  bool _isLoggingOut = false;

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

  @override
  Widget build(BuildContext context) {
    final titles = ['خانه', 'گفتگوها', 'افزودن پست', 'رویدادها', 'پروفایل من'];

    return Scaffold(
      appBar: AppBar(title: Text(titles[_currentIndex])),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(user: widget.user),
          const _PlaceholderTab(
            icon: Icons.chat_bubble_outline,
            title: 'گفتگوها',
            description: 'گفتگوهای خصوصی در این بخش قرار می‌گیرند.',
          ),
          const _PlaceholderTab(
            icon: Icons.add_circle_outline,
            title: 'افزودن پست',
            description: 'امکان انتشار پست در مرحله بعد اضافه می‌شود.',
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
        },
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'سلام ${user.displayName}!',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('به رستگاری جاوید خوش آمدی.'),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.favorite_border, size: 32),
                const SizedBox(height: 12),
                Text(
                  'اینجا برای همراهی هستیم',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'در این فضا می‌توانیم تجربه‌ها، خاطره‌ها و '
                  'مطالبی را به اشتراک بگذاریم که به همدلی '
                  'و همراهی افراد کمک می‌کنند.',
                ),
              ],
            ),
          ),
        ),
      ],
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
