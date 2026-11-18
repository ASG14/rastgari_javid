import 'package:flutter/material.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../memorial_profiles/presentation/screens/memorial_profile_form_screen.dart';
import '../../models/post.dart';
import 'create_post_screen.dart';

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({
    super.key,
    required this.authRepository,
    required this.onPostCreated,
    required this.onMemorialProfileCreated,
  });

  final AuthRepository authRepository;
  final ValueChanged<Post> onPostCreated;
  final VoidCallback onMemorialProfileCreated;

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  Future<void> _openPostComposer() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('انتشار پست')),
          body: CreatePostScreen(
            authRepository: widget.authRepository,
            onPostCreated: (post) {
              Navigator.of(context).pop();
              widget.onPostCreated(post);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openMemorialProfileForm() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            MemorialProfileFormScreen(authRepository: widget.authRepository),
      ),
    );

    if (!mounted || result != true) return;

    widget.onMemorialProfileCreated();
  }

  Widget _buildChoiceCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required String buttonLabel,
    required VoidCallback onTap,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: foregroundColor, size: 30),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.9,
                ),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: Text(buttonLabel),
                  style: FilledButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          Text(
            'چه چیزی می‌خواهید ثبت کنید؟',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'یکی از گزینه‌های زیر را انتخاب کنید.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 22),
          _buildChoiceCard(
            context: context,
            icon: Icons.edit_note_rounded,
            title: 'انتشار پست',
            description: 'یک نوشته، تجربه، خاطره یا موضوع مرتبط با فرهنگ سوگ و همراهی با دیگران را با جامعه به اشتراک بگذارید.',
            buttonLabel: 'نوشتن پست',
            onTap: _openPostComposer,
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
          ),
          const SizedBox(height: 16),
          _buildChoiceCard(
            context: context,
            icon: Icons.favorite_rounded,
            title: 'ثبت عزیز آسمانی',
            description: 'صفحه‌ای برای گرامی‌داشت یاد عزیز ازدست‌رفته خود بسازید و اطلاعات و خاطرات او را ثبت کنید.',
            buttonLabel: 'ثبت پروفایل یادبود',
            onTap: _openMemorialProfileForm,
            backgroundColor: colors.tertiaryContainer,
            foregroundColor: colors.onTertiaryContainer,
          ),
        ],
      ),
    );
  }
}
