import 'package:flutter/material.dart';

import '../../models/notification_item.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    super.key,
    required this.notification,
    required this.time,
  });

  final NotificationItem notification;
  final String time;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: notification.isRead
            ? colors.surfaceContainerHighest
            : colors.primaryContainer,
        child: Icon(
          _iconForType(notification.type),
          color: notification.isRead ? colors.onSurfaceVariant : colors.primary,
        ),
      ),
      title: Text(
        notification.message,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: notification.isRead ? FontWeight.normal : FontWeight.w700,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notification.contentPreview != null) ...[
            const SizedBox(height: 6),
            Text(
              notification.contentPreview!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            time,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
      trailing: notification.isRead
          ? null
          : Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: colors.primary,
                shape: BoxShape.circle,
              ),
            ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'post_like':
        return Icons.favorite_outline;

      case 'post_comment':
        return Icons.mode_comment_outlined;

      case 'comment_reply':
        return Icons.reply_rounded;

      case 'user_follow':
        return Icons.person_add_alt_1_outlined;

      case 'follow_request':
        return Icons.person_add_outlined;

      case 'follow_request_accepted':
        return Icons.how_to_reg_outlined;

      default:
        return Icons.notifications_outlined;
    }
  }
}
