
import 'package:flutter/material.dart';

import '../../models/memorial_profile.dart';

class MemorialProfileCard extends StatelessWidget {
  const MemorialProfileCard({
    super.key,
    required this.profile,
    required this.onTap,
  });

  final MemorialProfile profile;
  final VoidCallback onTap;

  String _relationshipLabel(String? relationship) {
    return switch (relationship) {
      'mother' => 'مادر',
      'father' => 'پدر',
      'sister' => 'خواهر',
      'brother' => 'برادر',
      'child' => 'فرزند',
      'spouse' => 'همسر',
      'friend' => 'دوست',
      'other' => 'سایر',
      _ => 'مشخص نشده',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      color: colors.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  color: colors.onPrimaryContainer,
                  size: 30,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      profile.isCreator
                          ? 'سازنده پروفایل'
                          : 'نسبت: ${_relationshipLabel(profile.relationship)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline_rounded,
                          size: 15,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${profile.membersCount} همراه',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_left_rounded,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
