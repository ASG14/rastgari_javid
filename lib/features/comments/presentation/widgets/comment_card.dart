
import 'package:flutter/material.dart';

import '../../models/comment.dart';

class CommentCard extends StatelessWidget {
  const CommentCard({
    super.key,
    required this.comment,
    required this.timeLabel,
    required this.onReply,
    this.replyToName,
    this.isReplying = false,
  });

  final Comment comment;
  final String timeLabel;
  final VoidCallback onReply;
  final String? replyToName;
  final bool isReplying;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final author = comment.author;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isReplying
            ? colors.primaryContainer.withValues(alpha: 0.25)
            : colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isReplying
              ? colors.primary.withValues(alpha: 0.6)
              : colors.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colors.primaryContainer,
                child: Text(
                  author.displayName.isNotEmpty
                      ? author.displayName[0]
                      : '؟',
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '@${author.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeLabel,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (replyToName != null) ...[
            Text(
              'در پاسخ به $replyToName',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
          ],
          Text(
            comment.content,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.9),
          ),
          const SizedBox(height: 5),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: onReply,
              icon: Icon(
                isReplying
                    ? Icons.edit_note_rounded
                    : Icons.reply_rounded,
                size: 18,
              ),
              label: Text(isReplying ? 'در حال پاسخ' : 'پاسخ'),
            ),
          ),
        ],
      ),
    );
  }
}
