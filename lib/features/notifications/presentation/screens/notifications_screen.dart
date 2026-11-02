import 'package:flutter/material.dart';

import '../../data/notification_repository.dart';
import '../../models/notification_item.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.repository});

  final NotificationRepository repository;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationItem> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.repository.getNotifications();

      final notifications = result.map(NotificationItem.fromJson).toList();

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(NotificationItem notification) async {
    if (notification.isRead) return;

    try {
      await widget.repository.markAsRead(notification.id);

      if (!mounted) return;

      setState(() {
        _notifications = _notifications.map((item) {
          if (item.id != notification.id) return item;

          return NotificationItem(
            id: item.id,
            type: item.type,
            postId: item.postId,
            commentId: item.commentId,
            createdAt: item.createdAt,
            readAt: DateTime.now(),
            isRead: true,
            actorId: item.actorId,
            actorUsername: item.actorUsername,
            actorDisplayName: item.actorDisplayName,
          );
        }).toList();
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('علامت‌گذاری اعلان ناموفق بود: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.isNegative || difference.inMinutes < 1) {
      return 'همین حالا';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} روز پیش';
    }

    final localDate = date.toLocal();

    return '${localDate.year}/${localDate.month.toString().padLeft(2, '0')}/${localDate.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('اعلان‌ها')),
        body: RefreshIndicator(
          onRefresh: _loadNotifications,
          child: _buildBody(context),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: 300,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 16),
          const Center(child: Text('دریافت اعلان‌ها ناموفق بود.')),
          const SizedBox(height: 8),
          Center(child: Text(_errorMessage!, textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _loadNotifications,
              icon: const Icon(Icons.refresh),
              label: const Text('تلاش مجدد'),
            ),
          ),
        ],
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 110),
          Icon(
            Icons.notifications_none_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'اعلانی نداری',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'وقتی کسی با نوشته‌ها یا دیدگاه‌هایت تعامل کند، اعلان‌ها اینجا نمایش داده می‌شوند.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _notifications.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final notification = _notifications[index];

        return ListTile(
          onTap: () => _markAsRead(notification),
          leading: CircleAvatar(
            backgroundColor: notification.isRead
                ? Theme.of(context).colorScheme.surfaceContainerHighest
                : Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              _iconForType(notification.type),
              color: notification.isRead
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            notification.message,
            style: TextStyle(
              fontWeight: notification.isRead
                  ? FontWeight.normal
                  : FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_formatDate(notification.createdAt)),
          ),
          trailing: notification.isRead
              ? null
              : Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
        );
      },
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
      default:
        return Icons.notifications_outlined;
    }
  }
}
