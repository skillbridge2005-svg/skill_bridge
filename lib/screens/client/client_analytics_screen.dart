import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// =============================================================================
// THEME + SHARED HELPERS
// =============================================================================

class _T {
  static const Color primary = Color(0xFF2563EB);
  static const Color navy = Color(0xFF0F172A);
  static const Color purple = Color(0xFF7C3AED);
  static const Color green = Color(0xFF10B981);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color cyan = Color(0xFF0891B2);
  static const Color pink = Color(0xFFDB2777);
  static const Color background = Color(0xFFF4F6FB);
  static const Color muted = Color(0xFF64748B);
  static const Color line = Color(0xFFE9EEF5);

  static const List<String> statuses = [
    'requirement',
    'team_formation',
    'development',
    'testing',
    'client_review',
    'completed',
    'cancelled',
  ];

  static const List<Color> statusColors = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFFF59E0B),
    Color(0xFFEC4899),
    Color(0xFF10B981),
    Color(0xFFEF4444),
  ];

  static const List<IconData> statusIcons = [
    Icons.edit_note_rounded,
    Icons.groups_rounded,
    Icons.code_rounded,
    Icons.bug_report_rounded,
    Icons.rate_review_rounded,
    Icons.verified_rounded,
    Icons.block_rounded,
  ];

  static const List<String> months = [
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

  static String normalizeStatus(dynamic value) {
    if (value == null) return 'unknown';
    return value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_');
  }

  static String prettyStatus(String status) {
    if (!statuses.contains(status)) return 'Other';
    return status
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String shortStatus(String status) {
    switch (status) {
      case 'requirement':
        return 'Brief';
      case 'team_formation':
        return 'Team';
      case 'development':
        return 'Build';
      case 'testing':
        return 'Test';
      case 'client_review':
        return 'Review';
      case 'completed':
        return 'Done';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  static DateTime? dateOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static DateTime? activityDate(Map<String, dynamic> p) =>
      dateOf(p['updatedAt']) ?? dateOf(p['createdAt']);

  static String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';

  static int countStatus(List<Map<String, dynamic>> projects, String status) {
    return projects.where((p) => normalizeStatus(p['status']) == status).length;
  }

  static Set<String> categoriesOf(Map<String, dynamic> project) {
    final result = <String>{};
    final rawCategories = project['categories'];
    final rawCategory = project['category'];

    if (rawCategories is List) {
      for (final value in rawCategories) {
        final c = value.toString().trim();
        if (c.isNotEmpty) result.add(c);
      }
    }
    if (rawCategory is String && rawCategory.trim().isNotEmpty) {
      result.add(rawCategory.trim());
    }
    return result;
  }

  static Map<String, int> categoryCounts(List<Map<String, dynamic>> projects) {
    final counts = <String, int>{};
    for (final p in projects) {
      for (final c in categoriesOf(p)) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Momentum score 0-100.
  /// 60% = average stage progress of non-cancelled projects
  /// 40% = share of projects that were NOT cancelled.
  static double momentumScore(List<Map<String, dynamic>> projects) {
    if (projects.isEmpty) return 0;
    final cancelled = countStatus(projects, 'cancelled');
    final live = projects.length - cancelled;

    double progressSum = 0;
    for (final p in projects) {
      final idx = statuses.indexOf(normalizeStatus(p['status']));
      if (idx < 0 || idx == 6) continue;
      progressSum += idx / 5.0; // requirement = 0 ... completed = 1
    }
    final avgProgress = live == 0 ? 0.0 : progressSum / live;
    final survival = 1 - cancelled / projects.length;
    return (avgProgress * 60 + survival * 40).clamp(0, 100).toDouble();
  }
}

// =============================================================================
// SCREEN
// =============================================================================

class ClientAnalyticsScreen extends StatefulWidget {
  const ClientAnalyticsScreen({super.key});

  @override
  State<ClientAnalyticsScreen> createState() => _ClientAnalyticsScreenState();
}

class _ClientAnalyticsScreenState extends State<ClientAnalyticsScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _stream;
  String? _uid;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  void _connect() {
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;
    if (user == null) {
      _stream = null;
      return;
    }
    _stream = FirebaseFirestore.instance
        .collection('projects')
        .where('clientId', isEqualTo: user.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || _stream == null) {
      return Scaffold(
        backgroundColor: _T.background,
        appBar: AppBar(title: const Text('Project Analytics')),
        body: const Center(
          child: Text('Please log in to view your project analytics.'),
        ),
      );
    }

    final firstName = (user.displayName ?? '').trim().split(' ').first;

    return Scaffold(
      backgroundColor: _T.background,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorView(
                message: 'Unable to load project analytics.',
                onRetry: () => setState(_connect),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: _T.primary),
              );
            }

            final projects = (snapshot.data?.docs ?? []).map((doc) {
              return <String, dynamic>{...doc.data(), '_documentId': doc.id};
            }).toList();

            projects.sort((a, b) {
              final aDate =
                  _T.activityDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
              final bDate =
                  _T.activityDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
              return bDate.compareTo(aDate);
            });

            final sections = <Widget>[
              _KpiGrid(projects: projects),
              _SectionHeading(
                title: 'Delivery Journey',
                subtitle: 'Follow your projects from brief to done',
                icon: Icons.route_rounded,
                child: _PipelineJourney(projects: projects),
              ),
              _SectionHeading(
                title: 'Status Mix',
                subtitle: 'Tap a slice to explore it',
                icon: Icons.donut_large_rounded,
                child: _InteractiveDonut(projects: projects),
              ),
              _SectionHeading(
                title: 'Stage Radar',
                subtitle: 'The shape of your portfolio',
                icon: Icons.radar_rounded,
                child: _StageRadar(projects: projects),
              ),
              _SectionHeading(
                title: 'Momentum',
                subtitle: 'New projects over the last 6 months',
                icon: Icons.show_chart_rounded,
                child: _MomentumChart(projects: projects),
              ),
              _SectionHeading(
                title: 'Activity Heatmap',
                subtitle: 'Project updates across the last 12 weeks',
                icon: Icons.grid_view_rounded,
                child: _ActivityHeatmap(projects: projects),
              ),
              _SectionHeading(
                title: 'Category Leaderboard',
                subtitle: 'Where most of your work lives',
                icon: Icons.emoji_events_rounded,
                child: _CategoryLeaderboard(projects: projects),
              ),
              _SectionHeading(
                title: 'Smart Insights',
                subtitle: 'Quick takeaways from your data',
                icon: Icons.auto_awesome_rounded,
                child: _InsightsList(projects: projects),
              ),
              _SectionHeading(
                title: 'Milestone Badges',
                subtitle: 'Unlock them as your portfolio grows',
                icon: Icons.military_tech_rounded,
                child: _BadgesGrid(projects: projects),
              ),
              _SectionHeading(
                title: 'Recent Activity',
                subtitle: 'Your latest project updates',
                icon: Icons.history_rounded,
                child: _RecentTimeline(projects: projects),
              ),
              const Center(
                child: Text(
                  'SkillBridge • Project Analytics',
                  style: TextStyle(
                    color: _T.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ];

            return RefreshIndicator(
              color: _T.primary,
              onRefresh: () async {
                if (_uid == null) return;
                await FirebaseFirestore.instance
                    .collection('projects')
                    .where('clientId', isEqualTo: _uid)
                    .get(const GetOptions(source: Source.server));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _Hero(
                      name: firstName,
                      projects: projects,
                      onBack: () => Navigator.maybePop(context),
                    ),
                  ),
                  if (projects.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyProjectsView(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return _Reveal(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 26),
                              child: sections[index],
                            ),
                          );
                        }, childCount: sections.length),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// ENTRANCE ANIMATION
// =============================================================================

class _Reveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _Reveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final ms = 420 + math.min(index, 8) * 90;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      builder: (context, value, c) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - value)),
            child: c,
          ),
        );
      },
      child: child,
    );
  }
}

// =============================================================================
// HERO WITH MOMENTUM GAUGE
// =============================================================================

class _Hero extends StatelessWidget {
  final String name;
  final List<Map<String, dynamic>> projects;
  final VoidCallback onBack;

  const _Hero({
    required this.name,
    required this.projects,
    required this.onBack,
  });

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _scoreLabel(double s) {
    if (s >= 75) return 'Flying';
    if (s >= 50) return 'Steady';
    if (s >= 25) return 'Warming up';
    return 'Just starting';
  }

  @override
  Widget build(BuildContext context) {
    final total = projects.length;
    final score = _T.momentumScore(projects);
    final hello = name.isEmpty ? _greeting() : '${_greeting()}, $name';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF4F46E5), Color(0xFF9333EA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: _T.purple.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -40,
            child: _Bubble(size: 150, alpha: 0.07),
          ),
          Positioned(
            left: -40,
            bottom: -70,
            child: _Bubble(size: 160, alpha: 0.06),
          ),
          Positioned(
            right: 70,
            bottom: 30,
            child: _Bubble(size: 26, alpha: 0.10),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onBack,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'SKILLBRIDGE ANALYTICS',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.auto_graph_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hello,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Your Project\nPulse',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.folder_copy_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$total ${total == 1 ? 'project' : 'projects'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _MomentumGauge(score: score, label: _scoreLabel(score)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final double size;
  final double alpha;

  const _Bubble({required this.size, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: alpha),
      ),
    );
  }
}

class _MomentumGauge extends StatelessWidget {
  final double score;
  final String label;

  const _MomentumGauge({required this.score, required this.label});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 118,
          height: 118,
          child: CustomPaint(
            painter: _GaugePainter(progress: value / 100),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value.round().toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;

  _GaugePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    const start = math.pi * 0.75;
    const sweep = math.pi * 1.5;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.16);

    canvas.drawArc(arcRect, start, sweep, false, track);

    if (progress <= 0) return;

    final active = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        startAngle: math.pi * 0.75,
        endAngle: math.pi * 2.25,
        colors: [Color(0xFF67E8F9), Color(0xFFA7F3D0), Color(0xFFFDE68A)],
      ).createShader(arcRect);

    canvas.drawArc(arcRect, start, sweep * progress.clamp(0, 1), false, active);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.progress != progress;
}

// =============================================================================
// SECTION WRAPPER
// =============================================================================

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _T.primary.withValues(alpha: 0.14),
                    _T.purple.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _T.primary, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _T.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _T.muted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Panel({required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _T.line),
        boxShadow: [
          BoxShadow(
            color: _T.navy.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =============================================================================
// KPI CARDS (COUNT-UP)
// =============================================================================

class _KpiGrid extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const _KpiGrid({required this.projects});

  @override
  Widget build(BuildContext context) {
    final total = projects.length;
    final completed = _T.countStatus(projects, 'completed');
    final cancelled = _T.countStatus(projects, 'cancelled');
    final active = total - completed - cancelled;

    final cards = [
      _KpiData('Total Projects', total, Icons.folder_special_rounded, const [
        Color(0xFF2563EB),
        Color(0xFF60A5FA),
      ]),
      _KpiData('Active Projects', active, Icons.rocket_launch_rounded, const [
        Color(0xFF7C3AED),
        Color(0xFFA78BFA),
      ]),
      _KpiData('Completed', completed, Icons.task_alt_rounded, const [
        Color(0xFF059669),
        Color(0xFF34D399),
      ]),
      _KpiData(
        'Cancelled',
        cancelled,
        Icons.cancel_presentation_rounded,
        const [Color(0xFFEA580C), Color(0xFFFB923C)],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 4 : 2;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (c) => SizedBox(
                  width: width,
                  child: _KpiCard(data: c),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _KpiData {
  final String title;
  final int value;
  final IconData icon;
  final List<Color> colors;

  const _KpiData(this.title, this.value, this.icon, this.colors);
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: data.colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: data.colors.first.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            top: -18,
            child: _Bubble(size: 78, alpha: 0.12),
          ),
          Positioned(
            right: 10,
            bottom: -4,
            child: Icon(
              data.icon,
              size: 54,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: Colors.white, size: 21),
              ),
              const SizedBox(height: 18),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: data.value.toDouble()),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) {
                  return Text(
                    v.round().toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                data.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DELIVERY JOURNEY (PIPELINE)
// =============================================================================

class _PipelineJourney extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const _PipelineJourney({required this.projects});

  @override
  Widget build(BuildContext context) {
    final counts = List.generate(
      6,
      (i) => _T.countStatus(projects, _T.statuses[i]),
    );
    final cancelled = _T.countStatus(projects, 'cancelled');
    final total = math.max(projects.length, 1);

    return _Panel(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(6, (i) {
              final color = _T.statusColors[i];
              final has = counts[i] > 0;

              return Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 3,
                            color: i == 0
                                ? Colors.transparent
                                : (counts[i - 1] > 0 || has)
                                ? color.withValues(alpha: 0.5)
                                : _T.line,
                          ),
                        ),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.6, end: 1),
                          duration: Duration(milliseconds: 500 + i * 120),
                          curve: Curves.elasticOut,
                          builder: (context, s, child) =>
                              Transform.scale(scale: s, child: child),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: has
                                  ? LinearGradient(
                                      colors: [
                                        color,
                                        color.withValues(alpha: 0.7),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              color: has ? null : const Color(0xFFF1F5F9),
                              boxShadow: has
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              _T.statusIcons[i],
                              size: 18,
                              color: has
                                  ? Colors.white
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 3,
                            color: i == 5
                                ? Colors.transparent
                                : (has || counts[i + 1] > 0)
                                ? _T.statusColors[i + 1].withValues(alpha: 0.5)
                                : _T.line,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${counts[i]}',
                      style: TextStyle(
                        color: has ? _T.navy : _T.muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _T.shortStatus(_T.statuses[i]),
                      style: const TextStyle(
                        color: _T.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 18),
          // Stacked share bar
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (var i = 0; i < 6; i++)
                    if (counts[i] > 0)
                      Expanded(
                        flex: counts[i],
                        child: Container(color: _T.statusColors[i]),
                      ),
                  if (cancelled > 0)
                    Expanded(
                      flex: cancelled,
                      child: Container(color: _T.statusColors[6]),
                    ),
                  if (counts.every((c) => c == 0) && cancelled == 0)
                    Expanded(child: Container(color: _T.line)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${((counts[5] / total) * 100).toStringAsFixed(0)}% reached completion',
                  style: const TextStyle(
                    color: _T.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (cancelled > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _T.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$cancelled cancelled',
                    style: const TextStyle(
                      color: _T.red,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// INTERACTIVE DONUT
// =============================================================================

class _InteractiveDonut extends StatefulWidget {
  final List<Map<String, dynamic>> projects;

  const _InteractiveDonut({required this.projects});

  @override
  State<_InteractiveDonut> createState() => _InteractiveDonutState();
}

class _InteractiveDonutState extends State<_InteractiveDonut> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final projects = widget.projects;
    final total = projects.length;

    // Entries: (label, color, count)
    final entries = <_SliceInfo>[];
    for (var i = 0; i < _T.statuses.length; i++) {
      final c = _T.countStatus(projects, _T.statuses[i]);
      if (c > 0) {
        entries.add(
          _SliceInfo(_T.prettyStatus(_T.statuses[i]), _T.statusColors[i], c),
        );
      }
    }
    final known = entries.fold<int>(0, (s, e) => s + e.count);
    if (total - known > 0) {
      entries.add(_SliceInfo('Other', const Color(0xFF94A3B8), total - known));
    }

    final sections = List.generate(entries.length, (i) {
      final selected = i == _touched;
      return PieChartSectionData(
        value: entries[i].count.toDouble(),
        color: entries[i].color,
        radius: selected ? 30 : 22,
        showTitle: false,
      );
    });

    final selected = (_touched >= 0 && _touched < entries.length)
        ? entries[_touched]
        : null;

    return _Panel(
      child: Column(
        children: [
          SizedBox(
            height: 230,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 70,
                    sectionsSpace: 4,
                    startDegreeOffset: -90,
                    borderData: FlBorderData(show: false),
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final idx =
                            response?.touchedSection?.touchedSectionIndex ?? -1;
                        final isEnd =
                            event is FlTapUpEvent || event is FlPanEndEvent;
                        setState(() => _touched = isEnd ? -1 : idx);
                      },
                    ),
                  ),
                  duration: const Duration(milliseconds: 350),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: Column(
                    key: ValueKey(selected?.label ?? 'total'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selected == null ? '$total' : '${selected.count}',
                        style: TextStyle(
                          color: selected?.color ?? _T.navy,
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        (selected?.label ?? 'PROJECTS').toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _T.muted,
                          fontSize: 10,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (selected != null && total > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${(selected.count / total * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: _T.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(entries.length, (i) {
              final e = entries[i];
              return GestureDetector(
                onTap: () => setState(() => _touched = _touched == i ? -1 : i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: i == _touched
                        ? e.color.withValues(alpha: 0.14)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: i == _touched ? e.color : _T.line,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: e.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '${e.label} · ${e.count}',
                        style: const TextStyle(
                          color: _T.navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SliceInfo {
  final String label;
  final Color color;
  final int count;

  const _SliceInfo(this.label, this.color, this.count);
}

// =============================================================================
// STAGE RADAR
// =============================================================================

class _StageRadar extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const _StageRadar({required this.projects});

  @override
  Widget build(BuildContext context) {
    final counts = List.generate(
      6,
      (i) => _T.countStatus(projects, _T.statuses[i]).toDouble(),
    );
    final maxValue = counts.fold<double>(0, math.max);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Projects per stage',
            style: TextStyle(
              color: _T.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'A wider shape in one corner means more projects sit in that stage.',
            style: TextStyle(color: _T.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 270,
            child: maxValue == 0
                ? const Center(
                    child: Text(
                      'Not enough data to draw the radar yet.',
                      style: TextStyle(color: _T.muted),
                    ),
                  )
                : RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.polygon,
                      tickCount: 3,
                      ticksTextStyle: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 8,
                      ),
                      tickBorderData: const BorderSide(
                        color: Color(0xFFE2E8F0),
                      ),
                      gridBorderData: const BorderSide(
                        color: Color(0xFFE2E8F0),
                      ),
                      radarBorderData: const BorderSide(
                        color: Colors.transparent,
                      ),
                      titlePositionPercentageOffset: 0.16,
                      titleTextStyle: const TextStyle(
                        color: _T.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                      getTitle: (index, angle) {
                        return RadarChartTitle(
                          text: _T.shortStatus(_T.statuses[index]),
                        );
                      },
                      dataSets: [
                        RadarDataSet(
                          fillColor: _T.purple.withValues(alpha: 0.22),
                          borderColor: _T.purple,
                          borderWidth: 2.5,
                          entryRadius: 4,
                          dataEntries: counts
                              .map((c) => RadarEntry(value: c))
                              .toList(),
                        ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 800),
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MOMENTUM LINE CHART
// =============================================================================

class _MomentumChart extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const _MomentumChart({required this.projects});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Last 6 months, oldest first.
    final monthStarts = List.generate(6, (i) {
      return DateTime(now.year, now.month - (5 - i), 1);
    });
    final counts = List<int>.filled(6, 0);
    var undated = 0;

    for (final p in projects) {
      final d = _T.dateOf(p['createdAt']);
      if (d == null) {
        undated++;
        continue;
      }
      for (var i = 0; i < 6; i++) {
        if (d.year == monthStarts[i].year && d.month == monthStarts[i].month) {
          counts[i]++;
          break;
        }
      }
    }

    final maxCount = counts.fold<int>(0, math.max);
    final maxY = math.max(2.0, maxCount + 1.0);
    final inWindow = counts.fold<int>(0, (s, c) => s + c);

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'New projects per month',
                  style: TextStyle(
                    color: _T.navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: _T.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$inWindow in 6 mo',
                  style: const TextStyle(
                    color: _T.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 5,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFFE9EEF5), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: maxY > 6 ? (maxY / 4).ceilToDouble() : 1,
                      getTitlesWidget: (value, meta) {
                        if (value != value.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: _T.muted, fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i > 5 || value != i.toDouble()) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _T.months[monthStarts[i].month - 1],
                            style: const TextStyle(
                              color: _T.muted,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) {
                      return spots.map((s) {
                        final n = s.y.toInt();
                        return LineTooltipItem(
                          '$n ${n == 1 ? 'project' : 'projects'}',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: List.generate(
                      6,
                      (i) => FlSpot(i.toDouble(), counts[i].toDouble()),
                    ),
                    isCurved: true,
                    curveSmoothness: 0.3,
                    preventCurveOverShooting: true,
                    barWidth: 4,
                    gradient: const LinearGradient(
                      colors: [_T.primary, _T.purple],
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: Colors.white,
                          strokeWidth: 3,
                          strokeColor: _T.purple,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _T.purple.withValues(alpha: 0.25),
                          _T.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 800),
            ),
          ),
          if (undated > 0)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '$undated ${undated == 1 ? 'project has' : 'projects have'} no creation date and ${undated == 1 ? 'is' : 'are'} not shown.',
                style: const TextStyle(color: _T.muted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// ACTIVITY HEATMAP (12 WEEKS)
// =============================================================================

class _ActivityHeatmap extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const _ActivityHeatmap({required this.projects});

  @override
  Widget build(BuildContext context) {
    const weeks = 12;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    // Week columns start on Monday; last column holds the current week.
    final currentMonday = todayDate.subtract(
      Duration(days: todayDate.weekday - 1),
    );
    final firstMonday = currentMonday.subtract(
      const Duration(days: 7 * (weeks - 1)),
    );

    final perDay = <DateTime, int>{};
    for (final p in projects) {
      final d = _T.activityDate(p);
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      perDay[day] = (perDay[day] ?? 0) + 1;
    }

    var maxPerDay = 0;
    var activeDays = 0;
    perDay.forEach((day, count) {
      if (!day.isBefore(firstMonday) && !day.isAfter(todayDate)) {
        maxPerDay = math.max(maxPerDay, count);
        activeDays++;
      }
    });

    Color colorFor(int count) {
      if (count <= 0) return const Color(0xFFEFF3F9);
      final t = maxPerDay <= 1 ? 1.0 : count / maxPerDay;
      return Color.lerp(const Color(0xFFC7D2FE), _T.purple, t) ?? _T.purple;
    }

    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: List.generate(7, (r) {
                  return Container(
                    width: 14,
                    height: 26,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      dayLabels[r],
                      style: const TextStyle(
                        color: _T.muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Row(
                  children: List.generate(weeks, (w) {
                    return Expanded(
                      child: Column(
                        children: List.generate(7, (r) {
                          final day = firstMonday.add(
                            Duration(days: w * 7 + r),
                          );
                          final future = day.isAfter(todayDate);
                          final count = perDay[day] ?? 0;
                          return Padding(
                            padding: const EdgeInsets.all(2),
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Tooltip(
                                message: future
                                    ? ''
                                    : '${_T.formatDate(day)}: $count ${count == 1 ? 'update' : 'updates'}',
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: future
                                        ? Colors.transparent
                                        : colorFor(count),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$activeDays active ${activeDays == 1 ? 'day' : 'days'} in 12 weeks',
                  style: const TextStyle(
                    color: _T.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Text(
                'Less',
                style: TextStyle(color: _T.muted, fontSize: 10),
              ),
              const SizedBox(width: 6),
              for (final t in [0, 1, 2, 3])
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: t == 0
                        ? const Color(0xFFEFF3F9)
                        : Color.lerp(
                            const Color(0xFFC7D2FE),
                            _T.purple,
                            (t - 1) / 2,
                          ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 3),
              const Text(
                'More',
                style: TextStyle(color: _T.muted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CATEGORY LEADERBOARD
// =============================================================================

class _CategoryLeaderboard extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const _CategoryLeaderboard({required this.projects});

  @override
  Widget build(BuildContext context) {
    final counts = _T.categoryCounts(projects);

    // Projects with no category at all.
    final uncategorized = projects
        .where((p) => _T.categoriesOf(p).isEmpty)
        .length;
    if (uncategorized > 0) counts['Uncategorized'] = uncategorized;

    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        if (c != 0) return c;
        return a.key.toLowerCase().compareTo(b.key.toLowerCase());
      });

    final top = sorted.take(6).toList();
    final maxCount = top.fold<int>(0, (m, e) => math.max(m, e.value));

    const palette = [
      _T.primary,
      _T.purple,
      _T.cyan,
      _T.green,
      _T.orange,
      _T.pink,
    ];
    const medals = ['🥇', '🥈', '🥉'];

    return _Panel(
      child: top.isEmpty
          ? const Text(
              'No category information is available yet.',
              style: TextStyle(color: _T.muted),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...List.generate(top.length, (i) {
                  final e = top[i];
                  final fraction = maxCount == 0 ? 0.0 : e.value / maxCount;
                  final color = palette[i % palette.length];

                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i == top.length - 1 ? 0 : 16,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 30,
                          child: i < 3
                              ? Text(
                                  medals[i],
                                  style: const TextStyle(fontSize: 19),
                                )
                              : Text(
                                  '#${i + 1}',
                                  style: const TextStyle(
                                    color: _T.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      e.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _T.navy,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${e.value} ${e.value == 1 ? 'project' : 'projects'}',
                                    style: const TextStyle(
                                      color: _T.muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: fraction),
                                  duration: Duration(
                                    milliseconds: 600 + i * 120,
                                  ),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, v, _) {
                                    return LinearProgressIndicator(
                                      value: v,
                                      minHeight: 9,
                                      backgroundColor: const Color(0xFFEDF1F7),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        color,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (sorted.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      '+ ${sorted.length - 6} more categories',
                      style: const TextStyle(
                        color: _T.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// =============================================================================
// SMART INSIGHTS
// =============================================================================

class _InsightData {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _InsightData(this.icon, this.color, this.title, this.description);
}

class _InsightsList extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const _InsightsList({required this.projects});

  @override
  Widget build(BuildContext context) {
    final total = projects.length;
    final completed = _T.countStatus(projects, 'completed');
    final cancelled = _T.countStatus(projects, 'cancelled');
    final active = total - completed - cancelled;
    final completionRate = total == 0 ? 0.0 : completed / total * 100;

    final statusCounts = <String, int>{
      for (final s in _T.statuses) s: _T.countStatus(projects, s),
    };
    final topStatus = statusCounts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topCategory = _T.categoryCounts(projects).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final recentDate = projects.isEmpty
        ? null
        : _T.activityDate(projects.first);

    final insights = <_InsightData>[
      _InsightData(
        Icons.task_alt_rounded,
        _T.green,
        'Completion rate',
        total == 0
            ? 'Create your first project to start tracking completion.'
            : '${completionRate.toStringAsFixed(1)}% of your projects are marked completed.',
      ),
      _InsightData(
        Icons.track_changes_rounded,
        _T.purple,
        'Most common status',
        topStatus.isEmpty
            ? 'Project status insights will appear here.'
            : '${_T.prettyStatus(topStatus.first.key)} has the highest count (${topStatus.first.value}).',
      ),
      _InsightData(
        Icons.category_rounded,
        _T.primary,
        'Popular category',
        topCategory.isEmpty
            ? 'Add categories to your projects to see category insights.'
            : '${topCategory.first.key} appears in ${topCategory.first.value} ${topCategory.first.value == 1 ? 'project' : 'projects'}.',
      ),
      _InsightData(
        Icons.bolt_rounded,
        _T.orange,
        'Active workload',
        '$active ${active == 1 ? 'project is' : 'projects are'} not marked completed or cancelled.',
      ),
      if (recentDate != null)
        _InsightData(
          Icons.update_rounded,
          _T.cyan,
          'Latest recorded activity',
          'Most recent project timestamp: ${_T.formatDate(recentDate)}.',
        ),
    ];

    return Column(
      children: insights.map((d) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _InsightCard(data: d),
        );
      }).toList(),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final _InsightData data;

  const _InsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _T.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: data.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 43,
                      height: 43,
                      decoration: BoxDecoration(
                        color: data.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(data.icon, color: data.color, size: 22),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.title,
                            style: const TextStyle(
                              color: _T.navy,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            data.description,
                            style: const TextStyle(
                              color: _T.muted,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MILESTONE BADGES
// =============================================================================

class _Badge {
  final String title;
  final String hint;
  final IconData icon;
  final Color color;
  final bool unlocked;

  const _Badge(this.title, this.hint, this.icon, this.color, this.unlocked);
}

class _BadgesGrid extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const _BadgesGrid({required this.projects});

  @override
  Widget build(BuildContext context) {
    final total = projects.length;
    final completed = _T.countStatus(projects, 'completed');
    final cancelled = _T.countStatus(projects, 'cancelled');
    final active = total - completed - cancelled;
    final categories = _T.categoryCounts(projects).length;

    final badges = [
      _Badge(
        'Kick-off',
        'Create a project',
        Icons.flag_rounded,
        _T.primary,
        total >= 1,
      ),
      _Badge(
        'Finisher',
        'Complete 1 project',
        Icons.verified_rounded,
        _T.green,
        completed >= 1,
      ),
      _Badge(
        'Juggler',
        'Run 3 active projects',
        Icons.bolt_rounded,
        _T.orange,
        active >= 3,
      ),
      _Badge(
        'Explorer',
        'Use 3 categories',
        Icons.explore_rounded,
        _T.cyan,
        categories >= 3,
      ),
      _Badge(
        'Closer',
        'Complete 5 projects',
        Icons.emoji_events_rounded,
        _T.purple,
        completed >= 5,
      ),
      _Badge(
        'Portfolio Pro',
        'Reach 10 projects',
        Icons.workspace_premium_rounded,
        _T.pink,
        total >= 10,
      ),
    ];

    final unlockedCount = badges.where((b) => b.unlocked).length;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$unlockedCount of ${badges.length} unlocked',
            style: const TextStyle(
              color: _T.navy,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 10.0;
              final columns = constraints.maxWidth >= 480 ? 3 : 2;
              final w =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: badges.map((b) {
                  return SizedBox(
                    width: w,
                    child: _BadgeTile(badge: b),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final _Badge badge;

  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final on = badge.unlocked;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: on
            ? badge.color.withValues(alpha: 0.07)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: on ? badge.color.withValues(alpha: 0.35) : _T.line,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? badge.color : const Color(0xFFE2E8F0),
            ),
            child: Icon(
              on ? badge.icon : Icons.lock_rounded,
              color: on ? Colors.white : const Color(0xFF94A3B8),
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  badge.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: on ? _T.navy : _T.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  badge.hint,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _T.muted,
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// RECENT ACTIVITY TIMELINE
// =============================================================================

class _RecentTimeline extends StatelessWidget {
  final List<Map<String, dynamic>> projects;

  const _RecentTimeline({required this.projects});

  @override
  Widget build(BuildContext context) {
    final recent = projects.take(5).toList();

    if (recent.isEmpty) {
      return const _Panel(
        child: Text(
          'Your recent projects will appear here.',
          style: TextStyle(color: _T.muted),
        ),
      );
    }

    return _Panel(
      child: Column(
        children: List.generate(recent.length, (index) {
          final project = recent[index];
          final title = (project['title'] ?? 'Untitled project')
              .toString()
              .trim();
          final status = _T.normalizeStatus(project['status']);
          final statusIndex = _T.statuses.indexOf(status);
          final color = statusIndex >= 0
              ? _T.statusColors[statusIndex]
              : const Color(0xFF94A3B8);
          final icon = statusIndex >= 0
              ? _T.statusIcons[statusIndex]
              : Icons.folder_open_rounded;
          final date = _T.activityDate(project);
          final isLast = index == recent.length - 1;

          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 21),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 28,
                        margin: const EdgeInsets.only(top: 5),
                        color: _T.line,
                      ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.isEmpty ? 'Untitled project' : title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _T.navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _T.prettyStatus(status),
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              date == null
                                  ? 'Date unavailable'
                                  : _T.formatDate(date),
                              style: const TextStyle(
                                color: _T.muted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// =============================================================================
// EMPTY + ERROR STATES
// =============================================================================

class _EmptyProjectsView extends StatelessWidget {
  const _EmptyProjectsView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.7, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: Curves.elasticOut,
              builder: (context, s, child) =>
                  Transform.scale(scale: s, child: child),
              child: Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      _T.primary.withValues(alpha: 0.14),
                      _T.purple.withValues(alpha: 0.14),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: _T.primary,
                  size: 46,
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Your dashboard is waiting!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _T.navy,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Create your first project to unlock your momentum score, '
              'delivery journey, heatmap and milestone badges.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _T.muted, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to Profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: _T.red, size: 48),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection and Firestore permissions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _T.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
