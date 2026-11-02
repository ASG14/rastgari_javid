import 'package:flutter/material.dart';

import '../../data/notification_repository.dart';
import '../../models/notification_item.dart';
import '../widgets/notification_card.dart';

enum _NotificationFilter { all, empathy, conversations, friends }

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
  _NotificationFilter _selectedFilter = _NotificationFilter.all;

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
      final notifications = result.map(NotificationItem.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });

      if (notifications.any((item) => !item.isRead)) {
        try {
          await widget.repository.markAllAsRead();

          if (!mounted) return;

          final readAt = DateTime.now();

          setState(() {
            _notifications = _notifications.map((item) {
              if (item.isRead) return item;

              return NotificationItem(
                id: item.id,
                type: item.type,
                postId: item.postId,
                commentId: item.commentId,
                createdAt: item.createdAt,
                readAt: readAt,
                isRead: true,
                actorId: item.actorId,
                actorUsername: item.actorUsername,
                actorDisplayName: item.actorDisplayName,
                contentPreview: item.contentPreview,
              );
            }).toList();
          });
        } catch (_) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'اعلان‌ها نمایش داده شدند، اما خوانده‌شدن آن‌ها ثبت نشد.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  List<NotificationItem> get _filteredNotifications {
    switch (_selectedFilter) {
      case _NotificationFilter.all:
        return _notifications;

      case _NotificationFilter.empathy:
        return _notifications
            .where((item) => item.type == 'post_like')
            .toList();

      case _NotificationFilter.conversations:
        return _notifications
            .where(
              (item) =>
                  item.type == 'post_comment' || item.type == 'comment_reply',
            )
            .toList();

      case _NotificationFilter.friends:
        // تا زمانی که نوع اعلان دوستی در بک‌اند اضافه نشده،
        // این فیلتر نتیجه‌ای ندارد.
        return [];
    }
  }

  String _formatTime(DateTime date) {
    final localDate = date.toLocal();
    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _dateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final difference = today.difference(day).inDays;

    if (difference == 0) return 'امروز';
    if (difference == 1) return 'دیروز';

    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final dayNumber = date.day.toString().padLeft(2, '0');

    return '$year/$month/$dayNumber';
  }

  Widget _buildFilters() {
    const filters = <(_NotificationFilter, String)>[
      (_NotificationFilter.all, 'همه'),
      (_NotificationFilter.empathy, 'همدلی‌ها'),
      (_NotificationFilter.conversations, 'گفتگوها'),
      (_NotificationFilter.friends, 'دوستی‌ها'),
    ];

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (filter, label) = filters[index];

          return ChoiceChip(
            label: Text(label),
            selected: _selectedFilter == filter,
            onSelected: (_) {
              setState(() {
                _selectedFilter = filter;
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildDateSeparator(String label) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: 0.7,
              height: 1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: theme.colorScheme.outlineVariant,
              thickness: 0.7,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildNotificationItems(List<NotificationItem> notifications) {
    final items = <Widget>[];
    String? previousDateKey;

    for (final notification in notifications) {
      final date = notification.createdAt.toLocal();
      final dateKey = '${date.year}-${date.month}-${date.day}';

      if (dateKey != previousDateKey) {
        previousDateKey = dateKey;
        items.add(_buildDateSeparator(_dateLabel(date)));
      }

      items.add(
        NotificationCard(notification: notification, time: _formatTime(date)),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('اعلان‌ها')),
        body: Column(
          children: [
            _buildFilters(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadNotifications,
                child: _buildBody(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
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
          const Text(
            'دریافت اعلان‌ها ناموفق بود.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(_errorMessage!, textAlign: TextAlign.center),
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

    final notifications = _filteredNotifications;

    if (notifications.isEmpty) {
      final message = switch (_selectedFilter) {
        _NotificationFilter.all => 'اعلانی نداری.',
        _NotificationFilter.empathy => 'اعلان همدلی‌ای وجود ندارد.',
        _NotificationFilter.conversations => 'اعلان گفتگویی وجود ندارد.',
        _NotificationFilter.friends => 'اعلان‌های دوستی هنوز فعال نشده‌اند.',
      };

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.notifications_none_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 16),
      children: _buildNotificationItems(notifications),
    );
  }
}
