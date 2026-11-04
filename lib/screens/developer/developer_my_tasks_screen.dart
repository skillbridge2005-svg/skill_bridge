import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DeveloperMyTasksScreen extends StatefulWidget {
  const DeveloperMyTasksScreen({super.key});

  @override
  State<DeveloperMyTasksScreen> createState() => _DeveloperMyTasksScreenState();
}

class _DeveloperMyTasksScreenState extends State<DeveloperMyTasksScreen>
    with SingleTickerProviderStateMixin {
  static const Color primary = Color(0xFF4F46E5);
  static const Color background = Color(0xFFF7F8FC);
  static const Color muted = Color(0xFF64748B);
  static const Color ink = Color(0xFF0F172A);
  static const Color border = Color(0xFFE8EAF2);

  static const List<String> _statusOrder = [
    'todo',
    'in_progress',
    'review',
    'completed',
  ];

  String selectedFilter = 'All';
  String searchQuery = '';

  final TextEditingController searchController = TextEditingController();

  final List<String> filters = [
    'All',
    'To Do',
    'In Progress',
    'In Review',
    'Completed',
  ];

  /// Drives the floating bubbles in the hero and the empty state.
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _float.stop();
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    searchController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  /// Always returns one of the four known status keys.
  String normalizedStatus(dynamic raw) {
    final value = (raw ?? 'todo').toString();
    return _statusOrder.contains(value) ? value : 'todo';
  }

  String statusLabel(String status) {
    switch (status) {
      case 'todo':
        return 'To Do';
      case 'in_progress':
        return 'In Progress';
      case 'review':
        return 'In Review';
      case 'completed':
        return 'Completed';
      default:
        return 'To Do';
    }
  }

  Color statusColor(String status) {
    switch (status) {
      case 'todo':
        return const Color(0xFF64748B);
      case 'in_progress':
        return const Color(0xFF2563EB);
      case 'review':
        return const Color(0xFFD97706);
      case 'completed':
        return const Color(0xFF16A34A);
      default:
        return muted;
    }
  }

  IconData statusIcon(String status) {
    switch (status) {
      case 'todo':
        return Icons.radio_button_unchecked_rounded;
      case 'in_progress':
        return Icons.timelapse_rounded;
      case 'review':
        return Icons.rate_review_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  /// The next step in the workflow (null when already completed).
  String? nextStatus(String status) {
    final index = _statusOrder.indexOf(status);
    if (index < 0 || index >= _statusOrder.length - 1) return null;
    return _statusOrder[index + 1];
  }

  String advanceLabel(String status) {
    switch (status) {
      case 'todo':
        return 'Start working';
      case 'in_progress':
        return 'Send to review';
      case 'review':
        return 'Mark as complete';
      default:
        return 'Completed';
    }
  }

  Color priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFDC2626);
      case 'medium':
        return const Color(0xFFD97706);
      case 'low':
        return const Color(0xFF16A34A);
      default:
        return const Color(0xFF64748B);
    }
  }

  int priorityRank(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 0;
      case 'medium':
        return 1;
      case 'low':
        return 2;
      default:
        return 3;
    }
  }

  String priorityLabel(String priority) {
    if (priority.isEmpty) return 'Normal';

    return priority[0].toUpperCase() + priority.substring(1);
  }

  String formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently updated';

    try {
      final date = (timestamp as Timestamp).toDate();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return 'Recently updated';
    }
  }

  String projectName(Map<String, dynamic> data) {
    final value = data['projectTitle'] ?? data['projectId'];
    final text = (value ?? '').toString().trim();
    return text.isEmpty ? 'No project' : text;
  }

  String? filterStatusKey(String label) {
    switch (label) {
      case 'To Do':
        return 'todo';
      case 'In Progress':
        return 'in_progress';
      case 'In Review':
        return 'review';
      case 'Completed':
        return 'completed';
      default:
        return null;
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _greetingLine {
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim() ?? '';
    final first = name.isEmpty ? '' : name.split(' ').first;
    return first.isEmpty ? _greeting : '$_greeting, $first';
  }

  String get _todayLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  String _motivation(int total, double progress) {
    if (total == 0)
      return 'No tasks yet — enjoy the calm before the next sprint.';
    if (progress >= 1) return 'Everything is done. You are on fire!';
    if (progress >= 0.6) return 'Almost there — keep the momentum going.';
    if (progress > 0) return 'Great start. One task at a time.';
    return 'Pick your first task and get the ball rolling.';
  }

  Future<void> updateTaskStatus(
    DocumentReference reference,
    String status,
  ) async {
    HapticFeedback.selectionClick();

    try {
      await reference.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      final done = status == 'completed';

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                done ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  done
                      ? 'Task completed — great job!'
                      : 'Task moved to ${statusLabel(status)}',
                ),
              ),
            ],
          ),
          backgroundColor: done ? const Color(0xFF16A34A) : primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update task: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ------------------------------------------------------------
  // HERO
  // ------------------------------------------------------------

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero({
    required double width,
    required int total,
    required int completed,
    required int inProgress,
    required int review,
    required double progress,
  }) {
    final compact = width < 400;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.30),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(painter: _BubblesPainter(_float)),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 18 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: Colors.white,
                        size: 25,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'MY WORKSPACE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.white,
                            size: 12,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _todayLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Text(
                  _greetingLine,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your tasks.\nYour progress.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 25 : 30,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _motivation(total, progress),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: compact ? 92 : 108,
                      height: compact ? 92 : 108,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: progress),
                        duration: const Duration(milliseconds: 1100),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _RingPainter(value),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${(value * 100).round()}%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: compact ? 20 : 24,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '$completed/$total done',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _heroChip(
                            Icons.timelapse_rounded,
                            '$inProgress in progress',
                          ),
                          _heroChip(
                            Icons.rate_review_rounded,
                            '$review in review',
                          ),
                          _heroChip(Icons.task_alt_rounded, '$completed done'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // STATS
  // ------------------------------------------------------------

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required String filter,
  }) {
    final selected = selectedFilter == filter;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => selectedFilter = filter);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : border,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (selected)
                    Icon(Icons.filter_alt_rounded, color: color, size: 16),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: value),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Text(
                      '$v',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: ink,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowCard(Map<String, int> counts, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.stacked_bar_chart_rounded,
                size: 18,
                color: primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Workflow',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const Spacer(),
              Text(
                '$total total',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: total == 0
                  ? Container(color: border)
                  : Row(
                      children: [
                        for (final s in _statusOrder)
                          if ((counts[s] ?? 0) > 0)
                            Expanded(
                              flex: counts[s]!,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: statusColor(s),
                                  border: const Border(
                                    right: BorderSide(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final s in _statusOrder)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor(s),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${statusLabel(s)} · ${counts[s] ?? 0}',
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // FOCUS CARD
  // ------------------------------------------------------------

  Widget _buildFocusCard(QueryDocumentSnapshot<Map<String, dynamic>> task) {
    final data = task.data();
    final status = normalizedStatus(data['status']);
    final priority = (data['priority'] ?? 'medium').toString();
    final title = (data['title'] ?? 'Untitled Task').toString();
    final next = nextStatus(status);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF312E81).withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD166).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFFFFD166),
                      size: 15,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'FOCUS NOW',
                      style: TextStyle(
                        color: Color(0xFFFFD166),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: priorityColor(priority).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flag_rounded,
                      color: Colors.white.withValues(alpha: 0.9),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      priorityLabel(priority),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  projectName(data),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: next == null
                      ? null
                      : () => updateTaskStatus(task.reference, next),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(advanceLabel(status)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon(status), color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel(status),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // FILTERS
  // ------------------------------------------------------------

  Widget _buildFilterPill({required String label, required int count}) {
    final selected = selectedFilter == label;
    final key = filterStatusKey(label);
    final color = key == null ? primary : statusColor(key);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => selectedFilter = label);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: selected ? color : border),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                key == null ? Icons.apps_rounded : statusIcon(key),
                size: 15,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: selected ? Colors.white : color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TASK CARD
  // ------------------------------------------------------------

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    QueryDocumentSnapshot<Map<String, dynamic>> task,
    int index,
  ) {
    final data = task.data();

    final title = (data['title'] ?? 'Untitled Task').toString();
    final description = (data['description'] ?? '').toString().trim();
    final status = normalizedStatus(data['status']);
    final priority = (data['priority'] ?? 'medium').toString();

    final currentStatusColor = statusColor(status);
    final currentPriorityColor = priorityColor(priority);
    final next = nextStatus(status);

    return TweenAnimationBuilder<double>(
      key: ValueKey(task.id),
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + math.min(index, 8) * 70),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) {
        return Opacity(
          opacity: v.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 22),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Status stripe on the left edge.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      currentStatusColor,
                      currentStatusColor.withValues(alpha: 0.45),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HEADER
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: currentStatusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            statusIcon(status),
                            color: currentStatusColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                softWrap: true,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: ink,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _pill(
                                    icon: Icons.flag_rounded,
                                    label:
                                        '${priorityLabel(priority)} Priority',
                                    color: currentPriorityColor,
                                  ),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 210,
                                    ),
                                    child: _pill(
                                      icon: Icons.folder_open_rounded,
                                      label: projectName(data),
                                      color: primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // DESCRIPTION
                  if (description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ),

                  // UPDATED DATE
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: muted,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Updated ${formatDate(data['updatedAt'])}',
                          style: const TextStyle(color: muted, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: border),

                  // STATUS JOURNEY + ACTION
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TASK JOURNEY · TAP A STEP TO UPDATE',
                          style: TextStyle(
                            color: muted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _StatusJourney(
                          status: status,
                          color: currentStatusColor,
                          onSelect: (value) {
                            if (value == status) return;
                            updateTaskStatus(task.reference, value);
                          },
                        ),
                        const SizedBox(height: 16),
                        if (next != null)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () =>
                                  updateTaskStatus(task.reference, next),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: Text(advanceLabel(status)),
                              style: FilledButton.styleFrom(
                                backgroundColor: currentStatusColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: currentStatusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.emoji_events_rounded,
                                  color: currentStatusColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Completed — nice work!',
                                  style: TextStyle(
                                    color: currentStatusColor,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // EMPTY STATE
  // ------------------------------------------------------------

  Widget _buildEmptyState({required bool hasAnyTasks}) {
    return Padding(
      padding: const EdgeInsets.all(35),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _float,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, math.sin(2 * math.pi * _float.value * 2) * 6),
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primary.withValues(alpha: 0.14),
                    const Color(0xFF9333EA).withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasAnyTasks
                    ? Icons.search_off_rounded
                    : Icons.auto_awesome_rounded,
                size: 55,
                color: primary,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            hasAnyTasks ? 'No matching tasks' : 'No tasks found',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasAnyTasks
                ? 'Try a different search or clear the filter.'
                : 'Assigned tasks will appear here.\n'
                      'Keep collaborating with your team!',
            textAlign: TextAlign.center,
            style: const TextStyle(color: muted, height: 1.6),
          ),
          if (hasAnyTasks) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                searchController.clear();
                setState(() {
                  searchQuery = '';
                  selectedFilter = 'All';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Clear filters'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primary,
                side: const BorderSide(color: primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    }

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'My Tasks',
          style: TextStyle(fontWeight: FontWeight.w800, color: ink),
        ),
        iconTheme: const IconThemeData(color: ink),
      ),

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collectionGroup('tasks')
            .where('assignedTo', isEqualTo: uid)
            .orderBy('updatedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load tasks.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final allTasks = snapshot.data?.docs ?? [];

          final total = allTasks.length;

          final counts = <String, int>{for (final s in _statusOrder) s: 0};
          for (final task in allTasks) {
            final key = normalizedStatus(task.data()['status']);
            counts[key] = (counts[key] ?? 0) + 1;
          }

          final completed = counts['completed'] ?? 0;
          final inProgress = counts['in_progress'] ?? 0;
          final pending = counts['todo'] ?? 0;
          final review = counts['review'] ?? 0;

          final progress = total == 0 ? 0.0 : completed / total;

          // The task to focus on next: highest priority, then furthest along.
          QueryDocumentSnapshot<Map<String, dynamic>>? focusTask;
          final open = allTasks
              .where((t) => normalizedStatus(t.data()['status']) != 'completed')
              .toList();
          if (open.isNotEmpty) {
            int statusRank(String s) =>
                s == 'in_progress' ? 0 : (s == 'review' ? 1 : 2);
            open.sort((a, b) {
              final pa = priorityRank(
                (a.data()['priority'] ?? 'medium').toString(),
              );
              final pb = priorityRank(
                (b.data()['priority'] ?? 'medium').toString(),
              );
              if (pa != pb) return pa.compareTo(pb);
              return statusRank(normalizedStatus(a.data()['status']))
                  .compareTo(statusRank(normalizedStatus(b.data()['status'])));
            });
            focusTask = open.first;
          }

          final query = searchQuery.toLowerCase();

          final filteredTasks = allTasks.where((task) {
            final data = task.data();

            final title = (data['title'] ?? '').toString().toLowerCase();

            final description = (data['description'] ?? '')
                .toString()
                .toLowerCase();

            final matchesSearch =
                title.contains(query) || description.contains(query);

            final matchesFilter =
                selectedFilter == 'All' ||
                statusLabel(normalizedStatus(data['status'])) == selectedFilter;

            return matchesSearch && matchesFilter;
          }).toList();

          return LayoutBuilder(
            builder: (context, constraints) {
              final width = math.min(constraints.maxWidth, 1100.0);

              // RESPONSIVE GRID
              final columns = width >= 650 ? 4 : 2;

              final horizontalPadding = width >= 1000 ? 28.0 : 16.0;

              final showFocus =
                  focusTask != null &&
                  selectedFilter == 'All' &&
                  searchQuery.isEmpty;

              return Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: CustomScrollView(
                    slivers: [
                      // HERO HEADER
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(horizontalPadding),
                          child: _buildHero(
                            width: width,
                            total: total,
                            completed: completed,
                            inProgress: inProgress,
                            review: review,
                            progress: progress,
                          ),
                        ),
                      ),

                      // STATISTICS (tap a card to filter)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                        ),
                        sliver: SliverGrid(
                          delegate: SliverChildListDelegate([
                            _buildStatCard(
                              title: 'Total Tasks',
                              value: total,
                              icon: Icons.assignment_rounded,
                              color: primary,
                              filter: 'All',
                            ),
                            _buildStatCard(
                              title: 'To Do',
                              value: pending,
                              icon: Icons.pending_actions_rounded,
                              color: const Color(0xFFD97706),
                              filter: 'To Do',
                            ),
                            _buildStatCard(
                              title: 'In Progress',
                              value: inProgress,
                              icon: Icons.timelapse_rounded,
                              color: const Color(0xFF2563EB),
                              filter: 'In Progress',
                            ),
                            _buildStatCard(
                              title: 'Completed',
                              value: completed,
                              icon: Icons.task_alt_rounded,
                              color: const Color(0xFF16A34A),
                              filter: 'Completed',
                            ),
                          ]),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisExtent: 128,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                        ),
                      ),

                      // WORKFLOW BAR
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            16,
                            horizontalPadding,
                            0,
                          ),
                          child: _buildWorkflowCard(counts, total),
                        ),
                      ),

                      // FOCUS CARD
                      if (showFocus)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              16,
                              horizontalPadding,
                              0,
                            ),
                            child: _buildFocusCard(focusTask),
                          ),
                        ),

                      // TASK TITLE
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            26,
                            horizontalPadding,
                            12,
                          ),
                          child: Row(
                            children: [
                              const Text(
                                'Assigned Tasks',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: primary.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${filteredTasks.length}',
                                  style: const TextStyle(
                                    color: primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // SEARCH
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: primary.withValues(alpha: 0.06),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: searchController,
                              onChanged: (value) {
                                setState(() {
                                  searchQuery = value;
                                });
                              },
                              decoration: InputDecoration(
                                hintText: 'Search tasks...',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded),
                                        onPressed: () {
                                          searchController.clear();
                                          setState(() {
                                            searchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // FILTER PILLS
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: 66,
                          child: ListView.separated(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: 14,
                            ),
                            scrollDirection: Axis.horizontal,
                            itemCount: filters.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final filter = filters[index];
                              final key = filterStatusKey(filter);
                              final count = key == null
                                  ? total
                                  : (counts[key] ?? 0);

                              return _buildFilterPill(
                                label: filter,
                                count: count,
                              );
                            },
                          ),
                        ),
                      ),

                      // EMPTY STATE
                      if (filteredTasks.isEmpty)
                        SliverToBoxAdapter(
                          child: _buildEmptyState(hasAnyTasks: total > 0),
                        )
                      // TASK LIST
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            8,
                            horizontalPadding,
                            30,
                          ),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return _buildTaskCard(
                                filteredTasks[index],
                                index,
                              );
                            }, childCount: filteredTasks.length),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// TASK JOURNEY (tappable 4-step status tracker)
// ============================================================================

class _StatusJourney extends StatelessWidget {
  const _StatusJourney({
    required this.status,
    required this.color,
    required this.onSelect,
  });

  final String status;
  final Color color;
  final ValueChanged<String> onSelect;

  static const List<String> _steps = [
    'todo',
    'in_progress',
    'review',
    'completed',
  ];
  static const List<String> _labels = ['To Do', 'Doing', 'Review', 'Done'];
  static const List<IconData> _icons = [
    Icons.inbox_rounded,
    Icons.bolt_rounded,
    Icons.rate_review_rounded,
    Icons.emoji_events_rounded,
  ];

  static const Color _idle = Color(0xFFE2E8F0);
  static const Color _idleBorder = Color(0xFFCBD5E1);

  @override
  Widget build(BuildContext context) {
    final current = _steps.indexOf(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_steps.length, (i) {
        final done = i < current;
        final isCurrent = i == current;
        final reached = done || isCurrent;

        return Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(_steps[i]),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 3,
                          color: i == 0
                              ? Colors.transparent
                              : (i <= current ? color : _idle),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: reached ? color : Colors.white,
                          border: Border.all(
                            color: reached ? color : _idleBorder,
                            width: 2,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.38),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : const [],
                        ),
                        child: done
                            ? const Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: Colors.white,
                              )
                            : isCurrent
                            ? Icon(_icons[i], size: 15, color: Colors.white)
                            : Text(
                                '${i + 1}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                      ),
                      Expanded(
                        child: Container(
                          height: 3,
                          color: i == _steps.length - 1
                              ? Colors.transparent
                              : (i < current ? color : _idle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _labels[i],
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isCurrent
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: reached ? color : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ============================================================================
// PAINTERS
// ============================================================================

/// Progress ring with a soft glow, used in the hero header.
class _RingPainter extends CustomPainter {
  const _RingPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final center = size.center(Offset.zero);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.white.withValues(alpha: 0.20),
    );

    if (value <= 0) return;

    final sweep = 2 * math.pi * value.clamp(0.0, 1.0);

    // Glow under the arc.
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.value != value;
}

/// Soft floating bubbles behind the hero content.
class _BubblesPainter extends CustomPainter {
  _BubblesPainter(this.animation) : super(repaint: animation);

  final Animation<double> animation;

  // fx, fy, radius, phase, speed (integer so the loop is seamless)
  static const List<List<double>> _specs = [
    [0.92, 0.12, 54, 0.0, 1],
    [0.78, 0.55, 30, 0.3, 2],
    [0.98, 0.85, 70, 0.6, 1],
    [0.55, 0.08, 18, 0.15, 2],
    [0.05, 0.92, 40, 0.8, 1],
    [0.40, 0.70, 14, 0.45, 2],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in _specs) {
      final t = animation.value * 2 * math.pi * s[4] + s[3] * 2 * math.pi;
      final center = Offset(
        size.width * s[0],
        size.height * s[1] + math.sin(t) * 10,
      );
      canvas.drawCircle(
        center,
        s[2],
        Paint()..color = Colors.white.withValues(alpha: 0.07),
      );
      canvas.drawCircle(
        center,
        s[2],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter old) => false;
}
