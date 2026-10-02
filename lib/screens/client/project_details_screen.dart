import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'client_messages_screen.dart';
import 'client_team_screen.dart';

class ProjectDetailsScreen extends StatelessWidget {
  final String projectId;

  const ProjectDetailsScreen({
    super.key,
    required this.projectId,
  });

  String _formatStatus(String status) {
    switch (status) {
      case 'requirement':
        return 'Requirement';
      case 'team_formation':
        return 'Team Formation';
      case 'development':
        return 'Development';
      case 'testing':
        return 'Testing';
      case 'client_review':
        return 'Client Review';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'requirement':
        return const Color(0xFF4F46E5);
      case 'team_formation':
        return const Color(0xFF7C3AED);
      case 'development':
        return const Color(0xFFD97706);
      case 'testing':
        return const Color(0xFF0891B2);
      case 'client_review':
        return const Color(0xFFDB2777);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'requirement':
        return Icons.description_outlined;
      case 'team_formation':
        return Icons.groups_outlined;
      case 'development':
        return Icons.code_rounded;
      case 'testing':
        return Icons.bug_report_outlined;
      case 'client_review':
        return Icons.rate_review_outlined;
      case 'completed':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }

  void _openTeam(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientTeamScreen(
          projectId: projectId,
        ),
      ),
    );
  }

  void _openMessages(
    BuildContext context,
    String projectTitle,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientProjectChat(
          projectId: projectId,
          projectTitle: projectTitle,
        ),
      ),
    );
  }

  bool _isStepActive(
    String currentStatus,
    String step,
  ) {
    const order = [
      'requirement',
      'team_formation',
      'development',
      'testing',
      'client_review',
      'completed',
    ];

    final currentIndex =
        order.indexOf(currentStatus);

    final stepIndex =
        order.indexOf(step);

    if (currentIndex == -1 ||
        stepIndex == -1) {
      return false;
    }

    return stepIndex <= currentIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 20,
        iconTheme: const IconThemeData(
          color: Color(0xFF111827),
        ),
        title: const Text(
          'Project Details',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ProjectDetailsAmbientPainter(),
              ),
            ),
          ),
          StreamBuilder<
              DocumentSnapshot<
                  Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(projectId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: _ProjectLoader(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(24),
                    child: _ProjectErrorCard(
                      message:
                          'Unable to load project.\n'
                          '${snapshot.error}',
                    ),
                  ),
                );
              }

              final document = snapshot.data;

              if (document == null ||
                  !document.exists) {
                return const Center(
                  child: Text(
                    'This project does not exist.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                );
              }

              final data = document.data();

              if (data == null) {
                return const Center(
                  child: Text(
                    'Project data is empty.',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                );
              }

              final title =
                  data['title']?.toString() ??
                      'Untitled Project';

              final category =
                  data['category']?.toString() ??
                      '';

              final description =
                  data['description']?.toString() ??
                      '';

              final requirements =
                  data['requirements']?.toString() ??
                      '';

              final budget =
                  data['budget']?.toString() ??
                      '';

              final timeline =
                  data['timeline']?.toString() ??
                      '';

              final status =
                  data['status']?.toString() ??
                      'requirement';

              final statusColor =
                  _statusColor(status);

              return LayoutBuilder(
                builder:
                    (context, constraints) {
                  final horizontalPadding =
                      constraints.maxWidth > 900
                          ? 28.0
                          : 20.0;

                  return SingleChildScrollView(
                    physics:
                        const BouncingScrollPhysics(),
                    padding:
                        EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      30,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(
                          maxWidth: 950,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .stretch,
                          children: [
                            _ProjectHero(
                              title: title,
                              category: category,
                              status: status,
                              statusColor:
                                  statusColor,
                              statusIcon:
                                  _statusIcon(
                                status,
                              ),
                              statusText:
                                  _formatStatus(
                                status,
                              ),
                            ),

                            const SizedBox(
                              height: 16,
                            ),

                            LayoutBuilder(
                              builder: (
                                context,
                                actionConstraints,
                              ) {
                                final buttons = [
                                  _ActionButton(
                                    icon: Icons
                                        .groups_outlined,
                                    title:
                                        'Project Team',
                                    subtitle:
                                        'View assigned developers',
                                    onTap: () =>
                                        _openTeam(
                                      context,
                                    ),
                                  ),
                                  _ActionButton(
                                    icon: Icons
                                        .chat_bubble_outline_rounded,
                                    title:
                                        'Project Messages',
                                    subtitle:
                                        'Chat with your team',
                                    onTap: () =>
                                        _openMessages(
                                      context,
                                      title,
                                    ),
                                  ),
                                ];

                                if (actionConstraints
                                        .maxWidth >
                                    650) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child:
                                            buttons[0],
                                      ),
                                      const SizedBox(
                                        width: 14,
                                      ),
                                      Expanded(
                                        child:
                                            buttons[1],
                                      ),
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    buttons[0],
                                    const SizedBox(
                                      height: 14,
                                    ),
                                    buttons[1],
                                  ],
                                );
                              },
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            _DetailsCard(
                              title:
                                  'Project Description',
                              icon: Icons
                                  .description_outlined,
                              child: Text(
                                description
                                        .isEmpty
                                    ? 'No description provided.'
                                    : description,
                                style:
                                    const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.65,
                                  color:
                                      Color(0xFF475467),
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            _DetailsCard(
                              title: 'Requirements',
                              icon: Icons
                                  .checklist_rounded,
                              child: Text(
                                requirements
                                        .isEmpty
                                    ? 'No requirements provided.'
                                    : requirements,
                                style:
                                    const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.65,
                                  color:
                                      Color(0xFF475467),
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            LayoutBuilder(
                              builder:
                                  (context,
                                      infoConstraints) {
                                final budgetCard =
                                    _InfoCard(
                                  icon: Icons
                                      .currency_rupee_rounded,
                                  title: 'Budget',
                                  value: budget
                                          .isEmpty
                                      ? 'Not specified'
                                      : budget,
                                );

                                final timelineCard =
                                    _InfoCard(
                                  icon: Icons
                                      .schedule_outlined,
                                  title: 'Timeline',
                                  value: timeline
                                          .isEmpty
                                      ? 'Not specified'
                                      : timeline,
                                );

                                if (infoConstraints
                                        .maxWidth <
                                    600) {
                                  return Column(
                                    children: [
                                      budgetCard,
                                      const SizedBox(
                                        height: 12,
                                      ),
                                      timelineCard,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(
                                      child:
                                          budgetCard,
                                    ),
                                    const SizedBox(
                                      width: 12,
                                    ),
                                    Expanded(
                                      child:
                                          timelineCard,
                                    ),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            _DetailsCard(
                              title:
                                  'Project Progress',
                              icon: Icons
                                  .timeline_rounded,
                              child:
                                  _ProgressTimeline(
                                currentStatus:
                                    status,
                                isStepActive:
                                    _isStepActive,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProjectHero extends StatelessWidget {
  final String title;
  final String category;
  final String status;
  final Color statusColor;
  final IconData statusIcon;
  final String statusText;

  const _ProjectHero({
    required this.title,
    required this.category,
    required this.status,
    required this.statusColor,
    required this.statusIcon,
    required this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF111827),
            Color(0xFF1E293B),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius:
            BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 25,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white
                      .withValues(alpha: 0.08),
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white
                        .withValues(alpha: 0.10),
                  ),
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  color: Color(0xFFA5B4FC),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  maxLines: 3,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 23,
                    height: 1.2,
                    fontWeight:
                        FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              if (category.isNotEmpty)
                _HeroChip(
                  icon:
                      Icons.category_outlined,
                  label: category,
                ),
              _HeroStatusChip(
                icon: statusIcon,
                label: statusText,
                color: statusColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white
            .withValues(alpha: 0.08),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white
              .withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.category_outlined,
            size: 14,
            color: Color(0xFFA5B4FC),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w700,
              color: Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeroStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.14),
        borderRadius:
            BorderRadius.circular(10),
        border: Border.all(
          color:
              color.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color:
                  const Color(0xFFE5E7EB),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEEF2FF),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      const Color(0xFF4F46E5),
                  size: 22,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            FontWeight.w900,
                        color:
                            Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        fontSize: 10.5,
                        color:
                            Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEEF2FF),
                  borderRadius:
                      BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons
                      .arrow_forward_rounded,
                  size: 16,
                  color:
                      Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _DetailsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(21),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFEEF2FF),
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color:
                      const Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(width: 11),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      Color(0xFF111827),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFEEF2FF),
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color:
                  const Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight.w700,
                    color:
                        Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        Color(0xFF111827),
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

class _ProgressTimeline extends StatelessWidget {
  final String currentStatus;
  final bool Function(
    String currentStatus,
    String step,
  ) isStepActive;

  const _ProgressTimeline({
    required this.currentStatus,
    required this.isStepActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ProgressStep(
          title: 'Requirement',
          icon: Icons.description_outlined,
          active: isStepActive(
            currentStatus,
            'requirement',
          ),
        ),
        _ProgressStep(
          title: 'Team Formation',
          icon: Icons.groups_outlined,
          active: isStepActive(
            currentStatus,
            'team_formation',
          ),
        ),
        _ProgressStep(
          title: 'Development',
          icon: Icons.code_rounded,
          active: isStepActive(
            currentStatus,
            'development',
          ),
        ),
        _ProgressStep(
          title: 'Testing',
          icon: Icons.bug_report_outlined,
          active: isStepActive(
            currentStatus,
            'testing',
          ),
        ),
        _ProgressStep(
          title: 'Client Review',
          icon: Icons.rate_review_outlined,
          active: isStepActive(
            currentStatus,
            'client_review',
          ),
        ),
        _ProgressStep(
          title: 'Completed',
          icon: Icons.check_circle_outline_rounded,
          active: isStepActive(
            currentStatus,
            'completed',
          ),
          isLast: true,
        ),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool active;
  final bool isLast;

  const _ProgressStep({
    required this.title,
    required this.icon,
    required this.active,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFEEF2FF)
                    : const Color(0xFFF8FAFC),
                borderRadius:
                    BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? const Color(0xFFC7D2FE)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Icon(
                active
                    ? Icons.check_rounded
                    : icon,
                size: 17,
                color: active
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF98A2B3),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 31,
                margin:
                    const EdgeInsets.symmetric(
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFC7D2FE)
                      : const Color(0xFFE5E7EB),
                  borderRadius:
                      BorderRadius.circular(2),
                ),
              ),
          ],
        ),
        const SizedBox(width: 13),
        Padding(
          padding:
              const EdgeInsets.only(top: 7),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active
                  ? FontWeight.w800
                  : FontWeight.w600,
              color: active
                  ? const Color(0xFF111827)
                  : const Color(0xFF98A2B3),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProjectLoader extends StatelessWidget {
  const _ProjectLoader();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Color(0xFF4F46E5),
      ),
    );
  }
}

class _ProjectErrorCard extends StatelessWidget {
  final String message;

  const _ProjectErrorCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          const BoxConstraints(
        maxWidth: 500,
      ),
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            const Color(0xFFFFFAEB),
        borderRadius:
            BorderRadius.circular(19),
        border: Border.all(
          color:
              const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color:
                  const Color(0xFFFFF1C2),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons
                  .warning_amber_rounded,
              color:
                  Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              message,
              style:
                  const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color:
                    Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectDetailsAmbientPainter
    extends CustomPainter {
  const _ProjectDetailsAmbientPainter();

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..style =
          PaintingStyle.fill;

    paint.color =
        const Color(0x0A4F46E5);

    canvas.drawCircle(
      Offset(
        size.width * 0.94,
        size.height * 0.09,
      ),
      190,
      paint,
    );

    paint.color =
        const Color(0x087C3AED);

    canvas.drawCircle(
      Offset(
        size.width * 0.04,
        size.height * 0.84,
      ),
      150,
      paint,
    );
  }

  @override
  bool shouldRepaint(
    covariant _ProjectDetailsAmbientPainter
        oldDelegate,
  ) {
    return false;
  }
}