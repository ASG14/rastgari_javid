
import 'package:flutter/material.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/models/auth_user.dart';
import 'navigation/main_navigation.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.user,
    required this.authRepository,
  });

  final AuthUser user;
  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return MainNavigation(
      user: user,
      authRepository: authRepository,
    );
  }
}
