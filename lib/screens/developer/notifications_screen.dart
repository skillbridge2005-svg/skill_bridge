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

  String _filter = 'All';
  String _query = '';
  bool _isClearing = false;

  static const _background = Color(0xFFF7F8FC);
  static const _ink = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _primary = Color(0xFF4F46E5);

  static const _filters = <String>[
    'All',
    'Unread',
    'Read',
    'Projects',
    'Applications',
    'Messages',
    'Teams',
    'Payments',
    'System Updates',
  ];

  bool get _mobile => MediaQuery.sizeOf(context).width < 600;

  String _category(String type) {
    final value = type.toLowerCase().replaceAll('-', '_');
    if (value.contains('application') ||
        value.contains('shortlist') ||
        value.contains('proposal')) {
      return 'Applications';
    }
    if (value.contains('project') ||
        value.contains('deadline') ||
        value.contains('milestone')) {
      return 'Projects';
    }
    if (value.contains('message') || value.contains('chat')) {
      return 'Messages';
    }
    if (value.contains('team') || value.contains('invitation')) {
      return 'Teams';
    }
    if (value.contains('payment') ||
        value.contains('refund') ||
        value.contains('invoice')) {
      return 'Payments';
    }
    if (value.contains('feature') ||
        value.contains('system') ||
        value.contains('maintenance') ||
        value.contains('announcement') ||
        value.contains('security') ||
        value.contains('account') ||
        value.contains('ai_')) {
      return 'System Updates';
    }
    return 'System Updates';
  }

  List<NotificationModel> _filtered(List<NotificationModel> items) {
    final query = _query.trim().toLowerCase();
    return items.where((item) {
      final category = _category(item.type);
      final filterMatches = switch (_filter) {
        'Unread' => item.isUnread,
        'Read' => item.isRead,
        'Projects' ||
        'Applications' ||
        'Messages' ||
        'Teams' ||
        'Payments' ||
        'System Updates' => category == _filter,
        _ => true,
      };
      final searchMatches =
          query.isEmpty ||
          item.title.toLowerCase().contains(query) ||
          item.body.toLowerCase().contains(query) ||
          item.type.toLowerCase().contains(query);
      return filterMatches && searchMatches;
    }).toList();
  }

  Future<void> _setRead(NotificationModel item, bool read) async {
    try {
      if (read) {
        await _service.markAsRead(item.id);
      } else {
        await _service.markAsUnread(item.id);
      }
      if (!mounted) return;
      _message(read ? 'Marked as read.' : 'Marked as unread.');
    } catch (_) {
      if (!mounted) return;
      _message('Could not update notification. Please try again.');
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _service.markAllAsRead();
      if (!mounted) return;
      _message('All notifications marked as read.');
    } catch (_) {
      if (!mounted) return;
      _message('Could not mark notifications as read. Please try again.');
    }
  }

  Future<void> _delete(NotificationModel item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete notification?'),
        content: const Text('This notification will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await _service.deleteNotification(item.id);
      if (!mounted) return;
      _message('Notification deleted.');
    } catch (_) {
      if (!mounted) return;
      _message('Could not delete notification. Please try again.');
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_sweep_outlined,
          color: Color(0xFFDC2626),
          size: 32,
        ),
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This permanently deletes all notifications in your account. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isClearing = true);
    try {
      await _service.clearAllNotifications();
      if (!mounted) return;
      _message('All notifications cleared.');
    } catch (_) {
      if (!mounted) return;
      _message('Could not clear notifications. Please try again.');
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _time(DateTime? date) {
    if (date == null) return 'Just now';
    final local = date.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24 && DateTime.now().day == local.day) {
      return '${diff.inHours}h ago';
    }
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  IconData _typeIcon(String type) {
    switch (_category(type)) {
      case 'Applications':
        return Icons.assignment_turned_in_outlined;
      case 'Projects':
        return Icons.work_outline_rounded;
      case 'Messages':
        return Icons.chat_bubble_outline_rounded;
      case 'Teams':
        return Icons.groups_2_outlined;
      case 'Payments':
        return Icons.payments_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (_category(type)) {
      case 'Applications':
        return const Color(0xFF059669);
      case 'Projects':
        return _primary;
      case 'Messages':
        return const Color(0xFF0284C7);
      case 'Teams':
        return const Color(0xFF9333EA);
      case 'Payments':
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = _mobile;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        top: false,
        child: StreamBuilder<List<NotificationModel>>(
          stream: _service.watchMyNotifications(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return _errorState();
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _primary),
              );
            }

            final all = snapshot.data ?? const <NotificationModel>[];
            final unread = all.where((item) => item.isUnread).length;
            final visible = _filtered(all);

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    mobile ? 14 : 28,
                    mobile ? 16 : 26,
                    mobile ? 14 : 28,
                    12,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        children: [
                          _summary(all.length, unread),
                          const SizedBox(height: 16),
                          TextField(
                            onChanged: (value) =>
                                setState(() => _query = value),
                            decoration: InputDecoration(
                              hintText: 'Search notifications...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: _primary,
                                  width: 1.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final filter in _filters)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(filter),
                                      selected: _filter == filter,
                                      onSelected: (_) =>
                                          setState(() => _filter = filter),
                                      selectedColor: const Color(0xFFE0E7FF),
                                      backgroundColor: Colors.white,
                                      side: BorderSide(
                                        color: _filter == filter
                                            ? const Color(0xFFC7D2FE)
                                            : const Color(0xFFE5E7EB),
                                      ),
                                      labelStyle: TextStyle(
                                        color: _filter == filter
                                            ? _primary
                                            : _muted,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (unread > 0)
                                TextButton.icon(
                                  onPressed: _markAllRead,
                                  icon: const Icon(
                                    Icons.done_all_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Mark all as read'),
                                ),
                              if (all.isNotEmpty)
                                TextButton.icon(
                                  onPressed: _isClearing ? null : _clearAll,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFDC2626),
                                  ),
                                  icon: _isClearing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_sweep_outlined,
                                          size: 18,
                                        ),
                                  label: const Text('Clear all'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? _emptyState(hasAny: all.isNotEmpty)
                      : Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: ListView.separated(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(
                                mobile ? 12 : 28,
                                4,
                                mobile ? 12 : 28,
                                28,
                              ),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) =>
                                  _notificationCard(visible[index]),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _summary(int total, int unread) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stay in the loop',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$total total · $unread unread',
                  style: const TextStyle(
                    color: Color(0xFFE0E7FF),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white70,
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _notificationCard(NotificationModel item) {
    final accent = _typeColor(item.type);
    final mobile = _mobile;
    return Container(
      decoration: BoxDecoration(
        color: item.isUnread ? const Color(0xFFFAFAFF) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.isUnread
              ? const Color(0xFFC7D2FE)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(mobile ? 13 : 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(_typeIcon(item.type), color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: item.isUnread ? () => _setRead(item, true) : null,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 7,
                        runSpacing: 5,
                        children: [
                          Text(
                            item.title.isEmpty ? 'Notification' : item.title,
                            style: TextStyle(
                              color: _ink,
                              fontSize: 14.5,
                              fontWeight: item.isUnread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                          if (item.isUnread)
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: _primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.body,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 5,
                        children: [
                          Text(
                            _time(item.createdAt),
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _category(item.type),
                              style: TextStyle(
                                color: accent,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Notification actions',
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_vert_rounded, color: _muted),
              onSelected: (action) {
                if (action == 'toggle') {
                  _setRead(item, item.isUnread);
                } else if (action == 'delete') {
                  _delete(item);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        item.isUnread
                            ? Icons.drafts_outlined
                            : Icons.mark_email_unread_outlined,
                        size: 19,
                      ),
                      const SizedBox(width: 10),
                      Text(item.isUnread ? 'Mark as read' : 'Mark as unread'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 19,
                        color: Color(0xFFDC2626),
                      ),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState({required bool hasAny}) {
    final filtered = _filter != 'All' || _query.trim().isNotEmpty;
    final title = filtered
        ? 'No matching notifications'
        : 'You’re all caught up';
    final description = filtered
        ? 'Try changing the filter or search term.'
        : hasAny
        ? 'There are no notifications in this view.'
        : 'New project, application, message, team, and platform updates will appear here.';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: _primary,
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: Color(0xFFDC2626),
              size: 48,
            ),
            const SizedBox(height: 14),
            const Text(
              'Unable to load notifications',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and Firestore permissions, then try again.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
