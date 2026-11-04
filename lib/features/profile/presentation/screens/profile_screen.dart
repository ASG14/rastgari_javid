import 'package:flutter/material.dart';

import '../../../auth/models/auth_user.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.isLoggingOut,
    required this.onLogout,
  });

  final AuthUser user;
  final bool isLoggingOut;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: colors.primaryContainer,
            child: Icon(
              Icons.person_outline,
              size: 48,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            user.displayName,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '@${user.username}',
            textDirection: TextDirection.ltr,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        if (user.email != null && user.email!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Center(child: Text(user.email!)),
        ],
        const SizedBox(height: 32),
        OutlinedButton.icon(
          onPressed: isLoggingOut ? null : onLogout,
          icon: const Icon(Icons.logout),
          label: Text(isLoggingOut ? 'در حال خروج...' : 'خروج از حساب'),
        ),
      ],
    );
  }
}
