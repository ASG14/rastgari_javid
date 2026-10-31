import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/models/auth_user.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/home/presentation/screens/home_screen.dart';
import 'app/app_shell.dart';

void main() {
  runApp(const RastgariJavidApp());
}

class RastgariJavidApp extends StatefulWidget {
  const RastgariJavidApp({super.key});

  @override
  State<RastgariJavidApp> createState() => _RastgariJavidAppState();
}

class _RastgariJavidAppState extends State<RastgariJavidApp> {
  late final AuthRepository _authRepository;

  AuthUser? _currentUser;
  bool _isCheckingSession = true;
  String? _sessionError;

  @override
  void initState() {
    super.initState();
    _authRepository = AuthRepository();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    setState(() {
      _isCheckingSession = true;
      _sessionError = null;
    });

    try {
      final user = await _authRepository.getCurrentUser();

      if (!mounted) return;

      setState(() {
        _currentUser = user;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _sessionError = error is ApiException
            ? error.message
            : 'ارتباط با سرور برقرار نشد. اتصال خود را بررسی کن.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingSession = false;
        });
      }
    }
  }

  void _continueToLogin() {
    setState(() {
      _currentUser = null;
      _sessionError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'رستگاری جاوید',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          alignLabelWithHint: true,
        ),
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_isCheckingSession) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('در حال بررسی وضعیت ورود...'),
            ],
          ),
        ),
      );
    }

    if (_sessionError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    size: 64,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'بررسی وضعیت ورود ناموفق بود.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(_sessionError!, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _restoreSession,
                    child: const Text('تلاش مجدد'),
                  ),
                  TextButton(
                    onPressed: _continueToLogin,
                    child: const Text('رفتن به صفحه ورود'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_currentUser != null) {
      return AppShell(user: _currentUser!, authRepository: _authRepository);
    }

    return LoginScreen(authRepository: _authRepository);
  }
}
