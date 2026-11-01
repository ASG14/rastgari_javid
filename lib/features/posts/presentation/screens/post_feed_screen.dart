
import 'package:flutter/material.dart';

import '../../../auth/models/auth_user.dart';
import '../../data/sample_posts.dart';
import '../widgets/post_card.dart';

class PostFeedScreen extends StatelessWidget {
  const PostFeedScreen({
    super.key,
    required this.user,
  });

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  colors.primaryContainer,
                  colors.surfaceContainerHighest,
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.spa_outlined,
                        color: colors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'رستگاری جاوید',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'فضایی برای شنیدن و همراهی',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  'سلام ${user.displayName}،',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'اینجا جایی است برای خاطره‌ها، تجربه‌ها و همراهی با یکدیگر.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.9,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                'تازه‌ترین نوشته‌ها',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.auto_awesome_outlined,
                color: colors.primary,
                size: 21,
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final post in samplePosts)
            PostCard(
              key: ValueKey(post.id),
              post: post,
              onCommentsTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('بخش گفتگوها در مرحله بعد اضافه می‌شود.'),
                  ),
                );
              },
              onShareTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('اشتراک‌گذاری در مرحله بعد اضافه می‌شود.'),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'پایان نوشته‌های آزمایشی',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
