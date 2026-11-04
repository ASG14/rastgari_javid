import 'package:flutter/material.dart';

import '../../../auth/models/auth_user.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.isLoggingOut,
    required this.onEditProfile,
    required this.onLogout,
  });

  final AuthUser user;
  final bool isLoggingOut;
  final VoidCallback onEditProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasBio = user.bio?.trim().isNotEmpty == true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: colors.primaryContainer,
            child: Icon(
              Icons.person_outline_rounded,
              size: 52,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          user.displayName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '@${user.username}',
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        if (user.email != null && user.email!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            user.email!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onEditProfile,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('ویرایش پروفایل'),
        ),
        const SizedBox(height: 24),
        _ProfileSection(
          title: 'درباره من',
          icon: Icons.notes_outlined,
          child: Text(
            hasBio ? user.bio! : 'هنوز توضیحی برای پروفایل خود ننوشته‌ای.',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.9,
              color: hasBio ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _ProfileSection(
          title: 'اطلاعات حساب',
          icon: Icons.manage_accounts_outlined,
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.alternate_email_rounded,
                label: 'نام کاربری',
                value: user.username,
                textDirection: TextDirection.ltr,
              ),
              if (user.email != null && user.email!.isNotEmpty) ...[
                const Divider(height: 24),
                _InfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'ایمیل',
                  value: user.email!,
                  textDirection: TextDirection.ltr,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: isLoggingOut ? null : onLogout,
          icon: isLoggingOut
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: Text(isLoggingOut ? 'در حال خروج...' : 'خروج از حساب'),
          style: OutlinedButton.styleFrom(
            foregroundColor: colors.error,
            side: BorderSide(color: colors.error.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colors.primary, size: 21),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.textDirection,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colors.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(value, textDirection: textDirection),
            ],
          ),
        ),
      ],
    );
  }
}
