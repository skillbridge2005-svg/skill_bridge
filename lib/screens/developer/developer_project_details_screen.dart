import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../client/client_messages_screen.dart';
import '../client/project_meeting_screen.dart';
import 'teams.dart';

class DeveloperProjectDetailsScreen extends StatelessWidget {
  final String projectId;

  const DeveloperProjectDetailsScreen({super.key, required this.projectId});

  static const Color primary = Color(0xFF4F46E5);
  static const Color background = Color(0xFFF7F8FC);
  static const Color dark = Color(0xFF111827);
  static const Color muted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  static const List<Map<String, String>> milestones = [
    {
      'key': 'requirements',
      'title': 'Requirements',
      'description': 'Finalize project requirements and specifications.',
    },
    {
      'key': 'architecture',
      'title': 'Architecture',
      'description': 'Define the system architecture and database design.',
    },
    {
      'key': 'design',
      'title': 'UI/UX Design',
      'description': 'Complete the user interface and experience design.',
    },
    {
      'key': 'development',
      'title': 'Development',
      'description': 'Implement the planned project functionality.',
    },
    {
      'key': 'testing',
      'title': 'Testing',
      'description': 'Test functionality and resolve identified issues.',
    },
    {
      'key': 'deployment',
      'title': 'Deployment',
      'description': 'Deploy the completed project.',
    },
  ];

  Future<bool> _isAuthorizedProjectMember(String currentUserId) async {
    // Ensure the supplied ID belongs to the currently signed-in user.
    if (FirebaseAuth.instance.currentUser?.uid != currentUserId) {
      return false;
    }

    // Load the project.
    final projectSnapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(projectId)
        .get();

    if (!projectSnapshot.exists) {
      return false;
    }

    final project = projectSnapshot.data();

    if (project == null) {
      return false;
    }

    // The directly assigned developer has access.
    if (project['developerId']?.toString() == currentUserId) {
      return true;
    }

    // Otherwise, check active teams associated with this project.
    final teamSnapshot = await FirebaseFirestore.instance
        .collection('teams')
        .where('projectId', isEqualTo: projectId)
        .where('memberIds', arrayContains: currentUserId)
        .get();

    return teamSnapshot.docs.any((doc) {
      final team = doc.data();

      return team['status']?.toString().trim().toLowerCase() == 'active';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Project Details',
          style: TextStyle(color: dark, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message(
              Icons.error_outline,
              'Unable to load project details.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primary),
            );
          }

          final document = snapshot.data;

          if (document == null || !document.exists) {
            return _message(Icons.folder_off_outlined, 'Project not found.');
          }

          final project = document.data() ?? {};

          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          if (currentUserId == null) {
            return _message(
              Icons.lock_outline,
              'Please sign in to access this project.',
            );
          }

          return FutureBuilder<bool>(
            future: _isAuthorizedProjectMember(currentUserId),
            builder: (context, accessSnapshot) {
              if (accessSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primary),
                );
              }

              if (accessSnapshot.hasError || accessSnapshot.data != true) {
                return _message(
                  Icons.lock_outline,
                  'You do not have access to this project.',
                );
              }

              final title = _string(
                project['title'],
                fallback: 'Untitled Project',
              );
              final status = _string(project['status'], fallback: 'active');

              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _projectHeader(title, project, status),
                  const SizedBox(height: 24),

                  // 1. Project Team
                  _section(
                    title: 'Project Team',
                    subtitle: 'Manage and view your project team.',
                    icon: Icons.groups_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoRow(
                          'Team Lead',
                          _string(
                            project['developerName'],
                            fallback: 'Assigned Developer',
                          ),
                        ),
                        const SizedBox(height: 14),
                        _actionButton(
                          icon: Icons.groups_2_outlined,
                          label: 'Open Project Team',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const Teams()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // 2. Project Conversation
                  _section(
                    title: 'Project Conversation',
                    subtitle: 'Keep project-related discussions together.',
                    icon: Icons.chat_bubble_outline,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Communicate with the client and discuss project updates.',
                          style: TextStyle(color: muted, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        _actionButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Open Project Conversation',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientProjectChat(
                                  projectId: projectId,
                                  projectTitle: title,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // 3. Schedule Meetings
                  _section(
                    title: 'Schedule Meetings',
                    subtitle: 'Coordinate with the client and team.',
                    icon: Icons.calendar_month_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Schedule a discussion or review meeting for this project.',
                          style: TextStyle(color: muted, height: 1.5),
                        ),
                        const SizedBox(height: 16),
                        _actionButton(
                          icon: Icons.calendar_month_rounded,
                          label: 'Schedule Meetings',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProjectMeetingScreen(
                                  projectId: projectId,
                                  projectTitle: title,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // 4. Description
                  _section(
                    title: 'Project Description',
                    subtitle: 'Understand the project objectives.',
                    icon: Icons.description_outlined,
                    child: Text(
                      _string(
                        project['description'],
                        fallback: 'No project description has been provided.',
                      ),
                      style: const TextStyle(
                        color: dark,
                        height: 1.7,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  // 5. Requirements
                  _section(
                    title: 'Requirements',
                    subtitle: 'Skills, technologies and project expectations.',
                    icon: Icons.checklist_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _listField('Required Skills', project['skills']),
                        _listField('Technologies', project['technologies']),
                        _listField(
                          'Other Requirements',
                          project['requirements'],
                        ),
                        _listField('Categories', project['categories']),
                      ],
                    ),
                  ),

                  // 6. Budget
                  _section(
                    title: 'Project Budget',
                    subtitle: 'Review the agreed project amount.',
                    icon: Icons.account_balance_wallet_outlined,
                    child: Column(
                      children: [
                        _budgetCard(project),
                        const SizedBox(height: 14),
                        _infoRow(
                          'Payment Type',
                          _string(
                            project['paymentType'],
                            fallback: 'Not specified',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 7. Timeline
                  _section(
                    title: 'Project Timeline',
                    subtitle: 'Review the expected schedule.',
                    icon: Icons.timeline_outlined,
                    child: Column(
                      children: [
                        _infoRow(
                          'Duration',
                          _string(
                            project['duration'],
                            fallback: 'Not specified',
                          ),
                        ),
                        const Divider(height: 28),
                        _infoRow(
                          'Start Date',
                          _formatDate(project['startDate']),
                        ),
                        const Divider(height: 28),
                        _infoRow(
                          'Expected Completion',
                          _formatDate(
                            project['expectedEndDate'] ?? project['endDate'],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 8. Project Progress
                  _section(
                    title: 'Project Progress',
                    subtitle:
                        'Complete each milestone to advance your project.',
                    icon: Icons.trending_up_outlined,
                    child: _projectProgressSection(context, project),
                  ),

                  // 9. Payment Status
                  _section(
                    title: 'Payment Status',
                    subtitle: 'Review available payment information.',
                    icon: Icons.payments_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _statusBadge(
                          _string(
                            project['paymentStatus'],
                            fallback: 'Not available',
                          ),
                        ),
                        const SizedBox(height: 18),
                        _infoRow(
                          'Project Amount',
                          _money(
                            project['budget'] ??
                                project['amount'] ??
                                project['projectAmount'],
                          ),
                        ),
                        const Divider(height: 28),
                        _infoRow('Paid Amount', _money(project['paidAmount'])),
                        const Divider(height: 28),
                        _infoRow(
                          'Pending Amount',
                          _money(project['pendingAmount']),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Payment information is displayed from available project '
                          'fields. Your existing payment records may require a '
                          'separate integration to show complete payment history.',
                          style: TextStyle(
                            color: muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _projectProgressSection(
    BuildContext context,
    Map<String, dynamic> project,
  ) {
    final rawMilestones = project['milestones'];
    final completedMilestones = rawMilestones is Map
        ? Map<String, dynamic>.from(rawMilestones)
        : <String, dynamic>{};

    final completedCount = milestones.where((milestone) {
      return completedMilestones[milestone['key']] == true;
    }).length;
    final totalMilestones = milestones.length;
    final progress = completedCount / totalMilestones;
    final currentIndex = milestones.indexWhere((milestone) {
      return completedMilestones[milestone['key']] != true;
    });
    final allCompleted = currentIndex == -1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Overall Completion',
              style: TextStyle(
                color: dark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                color: primary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: const Color(0xFFE5E7EB),
            color: allCompleted ? const Color(0xFF059669) : primary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$completedCount of $totalMilestones milestones completed',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 26),
        for (int i = 0; i < milestones.length; i++)
          _buildMilestoneTile(
            context: context,
            milestone: milestones[i],
            index: i,
            completedMilestones: completedMilestones,
            currentIndex: currentIndex,
            project: project,
          ),
        if (allCompleted)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF059669),
                  size: 28,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All milestones completed! '
                    'The project has reached 100% progress.',
                    style: TextStyle(
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMilestoneTile({
    required BuildContext context,
    required Map<String, String> milestone,
    required int index,
    required Map<String, dynamic> completedMilestones,
    required int currentIndex,
    required Map<String, dynamic> project,
  }) {
    final key = milestone['key']!;
    final isCompleted = completedMilestones[key] == true;
    final isCurrent = index == currentIndex;
    final isLocked = !isCompleted && !isCurrent;
    final isLast = index == milestones.length - 1;
    final milestoneColor = isCompleted
        ? const Color(0xFF059669)
        : isCurrent
        ? primary
        : const Color(0xFF9CA3AF);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFD1FAE5)
                        : isCurrent
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: milestoneColor, width: 1.5),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_rounded
                        : isLocked
                        ? Icons.lock_outline_rounded
                        : Icons.play_arrow_rounded,
                    color: milestoneColor,
                    size: 20,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted
                          ? const Color(0xFF059669)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 18),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFFF5F3FF) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent ? const Color(0xFFC7D2FE) : border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          milestone['title']!,
                          style: TextStyle(
                            color: isLocked ? muted : dark,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isCompleted)
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF059669),
                          size: 20,
                        )
                      else if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E7FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'CURRENT',
                            style: TextStyle(
                              color: primary,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else
                        const Text(
                          'LOCKED',
                          style: TextStyle(
                            color: muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    milestone['description']!,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _completeMilestone(
                            context: context,
                            milestoneKey: key,
                          );
                        },
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Mark as Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (isCompleted) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Completed successfully',
                      style: TextStyle(
                        color: Color(0xFF059669),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _completeMilestone({
    required BuildContext context,
    required String milestoneKey,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to update project progress.'),
        ),
      );
      return;
    }

    try {
      // Step 1: Check project membership before starting the transaction.
      final isAuthorized = await _isAuthorizedProjectMember(currentUserId);

      if (!context.mounted) return;

      if (!isAuthorized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are not authorized to update this project.'),
          ),
        );
        return;
      }

      // Step 2: Find the requested milestone.
      final milestoneIndex = milestones.indexWhere(
        (milestone) => milestone['key'] == milestoneKey,
      );

      if (milestoneIndex == -1) {
        return;
      }

      final projectRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId);

      // Step 3: Update the milestone transactionally.
      final didComplete = await FirebaseFirestore.instance.runTransaction<bool>(
        (transaction) async {
          final snapshot = await transaction.get(projectRef);

          if (!snapshot.exists) {
            throw StateError('Project not found.');
          }

          final data = snapshot.data();

          if (data == null) {
            throw StateError('Project data is unavailable.');
          }

          if (FirebaseAuth.instance.currentUser?.uid != currentUserId) {
            throw StateError('Your login session has changed.');
          }

          final rawMilestones = data['milestones'];
          final latestMilestones = rawMilestones is Map
              ? Map<String, dynamic>.from(rawMilestones)
              : <String, dynamic>{};

          const milestoneOrder = [
            'requirements',
            'architecture',
            'design',
            'development',
            'testing',
            'deployment',
          ];
          final currentIndex = milestoneOrder.indexOf(milestoneKey);

          if (currentIndex == -1) {
            throw StateError('Invalid milestone.');
          }

          if (latestMilestones[milestoneKey] == true) {
            return false;
          }

          for (int i = 0; i < currentIndex; i++) {
            if (latestMilestones[milestoneOrder[i]] != true) {
              throw StateError(
                'Complete ${milestones[i]['title']} first.',
              );
            }
          }

          latestMilestones[milestoneKey] = true;

          final completedCount = milestoneOrder
              .where((key) => latestMilestones[key] == true)
              .length;
          final progress =
              (completedCount / milestoneOrder.length * 100).round();
          final isCompleted = progress == 100;
          final updates = <String, dynamic>{
            'milestones': latestMilestones,
            'progress': progress,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (isCompleted) {
            updates['status'] = 'completed';
            updates['completedAt'] = FieldValue.serverTimestamp();
          }

          transaction.update(projectRef, updates);
          return true;
        },
      );

      if (!context.mounted || !didComplete) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${milestones[milestoneIndex]['title']} completed!'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      debugPrint('Project milestone update failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update progress: '
            '${e.toString().replaceFirst('Bad state: ', '')}',
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _projectHeader(
    String title,
    Map<String, dynamic> project,
    String status,
  ) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.15),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'YOUR ACTIVE PROJECT',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              _statusBadge(status, light: true),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Client: ${_string(project['clientName'], fallback: 'Client')}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _headerChip(
                Icons.work_outline,
                _string(project['projectType'], fallback: 'Project'),
              ),
              _headerChip(
                Icons.location_on_outlined,
                _string(project['workMode'], fallback: 'Not specified'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        color: dark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: muted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }

  Widget _budgetCard(Map<String, dynamic> project) {
    final amount =
        project['budget'] ?? project['amount'] ?? project['projectAmount'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Project Budget',
            style: TextStyle(color: muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            _money(amount),
            style: const TextStyle(
              color: primary,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _listField(String title, dynamic value) {
    final values = _toStringList(value);

    if (values.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: dark,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values
                .map(
                  (item) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(color: dark, fontSize: 12),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: muted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: dark,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: Color(0xFFC7D2FE)),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _headerChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status, {bool light = false}) {
    final normalized = status.toLowerCase();

    Color foreground = primary;
    Color fill = const Color(0xFFEEF2FF);

    if (normalized.contains('paid') || normalized == 'completed') {
      foreground = const Color(0xFF047857);
      fill = const Color(0xFFD1FAE5);
    } else if (normalized.contains('pending') ||
        normalized.contains('progress')) {
      foreground = const Color(0xFFB45309);
      fill = const Color(0xFFFEF3C7);
    } else if (normalized.contains('cancel') || normalized.contains('failed')) {
      foreground = const Color(0xFFB91C1C);
      fill = const Color(0xFFFEE2E2);
    }

    if (light) {
      fill = Colors.white.withValues(alpha: 0.18);
      foreground = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        _readable(status),
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _message(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: muted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  static String _string(dynamic value, {String fallback = 'Not specified'}) {
    if (value == null) return fallback;

    final result = value.toString().trim();
    return result.isEmpty ? fallback : result;
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(RegExp(r'[,;\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return [];
  }

  static String _money(dynamic value) {
    if (value == null) return 'Not specified';

    if (value is num) {
      return '₹${value.toStringAsFixed(2)}';
    }

    final parsed = num.tryParse(value.toString());

    if (parsed != null) {
      return '₹${parsed.toStringAsFixed(2)}';
    }

    return value.toString();
  }

  static String _formatDate(dynamic value) {
    if (value == null) return 'Not specified';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) return 'Not specified';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  static String _readable(String value) {
    if (value.isEmpty) return 'Not specified';

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}
