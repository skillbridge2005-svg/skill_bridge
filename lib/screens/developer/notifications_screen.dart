import 'package:flutter/material.dart';

import '../../models/notification_model.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  final TextEditingController _searchController = TextEditingController();

  String _filter = 'All';
  String _search = '';
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(NotificationModel item) {
    switch (_filter) {
      case 'Unread':
        return item.isUnread;
      case 'Projects':
        return item.type.toLowerCase().contains('project');
      case 'Applications':
        return item.type.toLowerCase().contains('application');
      case 'Messages':
        return item.type.toLowerCase().contains('message');
      case 'Teams':
        return item.type.toLowerCase().contains('team') ||
            item.type.toLowerCase().contains('invitation');
      default:
        return true;
    }
  }

  List<NotificationModel> _filterNotifications(List<NotificationModel> items) {
    final query = _search.trim().toLowerCase();

    return items.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.body.toLowerCase().contains(query) ||
          item.type.toLowerCase().contains(query);

      return matchesQuery && _matchesFilter(item);
    }).toList();
  }

  Future<void> _runAction(
    Future<void> Function() action,
    String successMessage,
  ) async {
    if (_busy) return;

    setState(() => _busy = true);

    try {
      await action();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Action failed: $error')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This permanently deletes all notifications '
          'belonging to your account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _runAction(_service.clearAllNotifications, 'Notifications cleared.');
  }

  IconData _iconFor(String type) {
    final value = type.toLowerCase();

    if (value.contains('application')) {
      return Icons.assignment_turned_in_outlined;
    }
    if (value.contains('project')) {
      return Icons.work_outline_rounded;
    }
    if (value.contains('message')) {
      return Icons.chat_bubble_outline_rounded;
    }
    if (value.contains('team') || value.contains('invitation')) {
      return Icons.groups_outlined;
    }

    return Icons.notifications_none_rounded;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Recently';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.isNegative) {
      return 'Just now';
    }
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    const filters = [
      'All',
      'Unread',
      'Projects',
      'Applications',
      'Messages',
      'Teams',
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          TextButton(
            onPressed: _busy
                ? null
                : () => _runAction(
                    _service.markAllAsRead,
                    'All notifications marked as read.',
                  ),
            child: const Text('Mark all read'),
          ),
          IconButton(
            tooltip: 'Clear all',
            onPressed: _busy ? null : _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<NotificationModel>>(
        stream: _service.watchMyNotifications(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load notifications.',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your connection, sign-in status '
                      'and Firestore security rules.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allItems = snapshot.data ?? <NotificationModel>[];
          final unreadCount = allItems.where((item) => item.isUnread).length;
          final items = _filterNotifications(allItems);

          return Column(
            children: [
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$unreadCount unread · '
                      '${allItems.length} total',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() => _search = value);
                      },
                      decoration: InputDecoration(
                        hintText: 'Search notifications...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _search.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _search = '');
                                },
                                icon: const Icon(Icons.close),
                              ),
                        filled: true,
                        fillColor: const Color(0xFFF6F8FC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: filters.map((filter) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(filter),
                              selected: _filter == filter,
                              onSelected: (_) {
                                setState(() => _filter = filter);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.notifications_none_rounded,
                                size: 56,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                allItems.isEmpty
                                    ? 'No notifications yet'
                                    : 'No matching notifications',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Updates will appear here when available.',
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];

                          return Card(
                            elevation: 0,
                            color: item.isUnread
                                ? const Color(0xFFEEF4FF)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: item.isUnread
                                    ? const Color(0xFFBFDBFE)
                                    : const Color(0xFFE5EAF2),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: const Color(0xFFDBEAFE),
                                    child: Icon(
                                      _iconFor(item.type),
                                      color: const Color(0xFF2563EB),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title.isEmpty
                                              ? 'Notification'
                                              : item.title,
                                          style: TextStyle(
                                            fontWeight: item.isUnread
                                                ? FontWeight.w800
                                                : FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(item.body),
                                        const SizedBox(height: 8),
                                        Text(
                                          _formatDate(item.createdAt),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 4,
                                          children: [
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _runAction(
                                                      () => item.isUnread
                                                          ? _service.markAsRead(
                                                              item.id,
                                                            )
                                                          : _service
                                                                .markAsUnread(
                                                                  item.id,
                                                                ),
                                                      item.isUnread
                                                          ? 'Marked as read.'
                                                          : 'Marked as unread.',
                                                    ),
                                              child: Text(
                                                item.isUnread
                                                    ? 'Mark read'
                                                    : 'Mark unread',
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: _busy
                                                  ? null
                                                  : () => _runAction(
                                                      () => _service
                                                          .deleteNotification(
                                                            item.id,
                                                          ),
                                                      'Notification deleted.',
                                                    ),
                                              child: const Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.redAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (item.isUnread)
                                    Container(
                                      width: 9,
                                      height: 9,
                                      margin: const EdgeInsets.only(
                                        top: 6,
                                        left: 8,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF2563EB),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
