import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../auth/models/auth_user.dart';
import '../../../auth/presentation/screens/login_screen.dart';

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
        SnackBar(
          content: Text('خروج از حساب با خطا مواجه شد: $error'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رستگاری جاوید'),
        actions: [
          IconButton(
            tooltip: 'خروج از حساب',
            onPressed: _isLoggingOut ? null : _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 88,
                color: Colors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                'سلام ${widget.user.displayName}!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'با موفقیت وارد حساب کاربری خود شدی.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text('نام کاربری: ${widget.user.username}'),
              if (widget.user.email != null &&
                  widget.user.email!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('ایمیل: ${widget.user.email}'),
              ],
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isLoggingOut ? null : _logout,
                icon: const Icon(Icons.logout),
                label: _isLoggingOut
                    ? const Text('در حال خروج...')
                    : const Text('خروج از حساب'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
