import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'client_messages_screen.dart';
import 'client_team_screen.dart';

class ProjectDetailsScreen extends StatelessWidget {
  final String projectId;

  const ProjectDetailsScreen({super.key, required this.projectId});

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
        return const Color(0xFF2563EB);
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

  void _openTeam(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClientTeamScreen(projectId: projectId)),
    );
  }

  void _openMessages(BuildContext context, String projectTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ClientProjectChat(projectId: projectId, projectTitle: projectTitle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Project Details',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load project.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final document = snapshot.data;

          if (document == null || !document.exists) {
            return const Center(child: Text('This project does not exist.'));
          }

          final data = document.data();

          if (data == null) {
            return const Center(child: Text('Project data is empty.'));
          }

          final title = data['title']?.toString() ?? 'Untitled Project';

          final category = data['category']?.toString() ?? '';

          final description = data['description']?.toString() ?? '';

          final requirements = data['requirements']?.toString() ?? '';

          final budget = data['budget']?.toString() ?? '';

          final timeline = data['timeline']?.toString() ?? '';

          final status = data['status']?.toString() ?? 'requirement';

          final statusColor = _statusColor(status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 950),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _formatStatus(status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (category.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              category,
                              style: const TextStyle(
                                color: Color(0xFF2563EB),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final buttons = [
                          _ActionButton(
                            icon: Icons.groups_outlined,
                            title: 'Project Team',
                            onTap: () => _openTeam(context),
                          ),
                          _ActionButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            title: 'Project Messages',
                            onTap: () => _openMessages(context, title),
                          ),
                        ];

                        if (constraints.maxWidth > 650) {
                          return Row(
                            children: [
                              Expanded(child: buttons[0]),
                              const SizedBox(width: 14),
                              Expanded(child: buttons[1]),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            buttons[0],
                            const SizedBox(height: 14),
                            buttons[1],
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    _DetailsCard(
                      title: 'Project Description',
                      icon: Icons.description_outlined,
                      child: Text(
                        description.isEmpty
                            ? 'No description provided.'
                            : description,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    _DetailsCard(
                      title: 'Requirements',
                      icon: Icons.checklist_rounded,
                      child: Text(
                        requirements.isEmpty
                            ? 'No requirements provided.'
                            : requirements,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final budgetCard = _InfoCard(
                          icon: Icons.currency_rupee_rounded,
                          title: 'Budget',
                          value: budget.isEmpty ? 'Not specified' : budget,
                        );

                        final timelineCard = _InfoCard(
                          icon: Icons.schedule_outlined,
                          title: 'Timeline',
                          value: timeline.isEmpty ? 'Not specified' : timeline,
                        );

                        if (constraints.maxWidth < 600) {
                          return Column(
                            children: [
                              budgetCard,
                              const SizedBox(height: 14),
                              timelineCard,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: budgetCard),
                            const SizedBox(width: 14),
                            Expanded(child: timelineCard),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    _DetailsCard(
                      title: 'Project Progress',
                      icon: Icons.timeline_rounded,
                      child: Column(
                        children: [
                          _ProgressStep(
                            title: 'Requirement',
                            active: _isStepActive(status, 'requirement'),
                          ),
                          _ProgressStep(
                            title: 'Team Formation',
                            active: _isStepActive(status, 'team_formation'),
                          ),
                          _ProgressStep(
                            title: 'Development',
                            active: _isStepActive(status, 'development'),
                          ),
                          _ProgressStep(
                            title: 'Testing',
                            active: _isStepActive(status, 'testing'),
                          ),
                          _ProgressStep(
                            title: 'Client Review',
                            active: _isStepActive(status, 'client_review'),
                          ),
                          _ProgressStep(
                            title: 'Completed',
                            active: _isStepActive(status, 'completed'),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isStepActive(String currentStatus, String step) {
    const order = [
      'requirement',
      'team_formation',
      'development',
      'testing',
      'client_review',
      'completed',
    ];

    final currentIndex = order.indexOf(currentStatus);

    final stepIndex = order.indexOf(step);

    if (currentIndex == -1 || stepIndex == -1) {
      return false;
    }

    return stepIndex <= currentIndex;
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ],
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2563EB)),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
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

class _ProgressStep extends StatelessWidget {
  final String title;
  final bool active;
  final bool isLast;

  const _ProgressStep({
    required this.title,
    required this.active,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFE2E8F0),
              ),
              child: active
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 30,
                color: active
                    ? const Color(0xFFBFDBFE)
                    : const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
