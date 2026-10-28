import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../widgets/skillbridge_avatar.dart';

class ClientApplicationsScreen extends StatelessWidget {
  final String projectId;
  final String projectTitle;

  const ClientApplicationsScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Color _statusColor(String status, ColorScheme colors) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.green;
      case 'shortlisted':
        return Colors.blue;
      case 'rejected':
        return colors.error;
      case 'withdrawn':
        return colors.outline;
      default:
        return Colors.orange;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return 'Accepted';
      case 'shortlisted':
        return 'Shortlisted';
      case 'rejected':
        return 'Rejected';
      case 'withdrawn':
        return 'Withdrawn';
      default:
        return 'Pending';
    }
  }

  Future<void> _updateStatus(
    BuildContext context,
    String applicationId,
    String newStatus,
  ) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage(context, 'Please log in to continue.');
      return;
    }

    // Only these actions are supported.
    const allowedStatuses = {'shortlisted', 'rejected', 'accepted'};

    if (!allowedStatuses.contains(newStatus)) {
      _showMessage(context, 'Invalid application status.');
      return;
    }

    try {
      final projectRef = _firestore.collection('projects').doc(projectId);
      final applicationRef = _firestore
          .collection('applications')
          .doc(applicationId);

      await _firestore.runTransaction((transaction) async {
        final projectSnapshot = await transaction.get(projectRef);
        final applicationSnapshot = await transaction.get(applicationRef);

        if (!projectSnapshot.exists) {
          throw Exception('PROJECT_NOT_FOUND');
        }

        if (!applicationSnapshot.exists) {
          throw Exception('APPLICATION_NOT_FOUND');
        }

        final projectData = projectSnapshot.data();
        final applicationData = applicationSnapshot.data();

        if (projectData == null || applicationData == null) {
          throw Exception('INVALID_DOCUMENT');
        }

        if (projectData['clientId'] != user.uid) {
          throw Exception('ACCESS_DENIED');
        }

        if (applicationData['projectId'] != projectId ||
            applicationData['clientId'] != user.uid) {
          throw Exception('APPLICATION_ACCESS_DENIED');
        }

        final currentApplicationStatus =
            (applicationData['status'] ?? 'pending')
                .toString()
                .trim()
                .toLowerCase();

        if (currentApplicationStatus != 'pending' &&
            currentApplicationStatus != 'shortlisted') {
          throw Exception('APPLICATION_ALREADY_PROCESSED');
        }

        final now = FieldValue.serverTimestamp();

        if (newStatus == 'accepted') {
          final existingDeveloperId = (projectData['developerId'] ?? '')
              .toString()
              .trim();
          final projectStatus = (projectData['status'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          if (existingDeveloperId.isNotEmpty || projectStatus == 'active') {
            throw Exception('PROJECT_ALREADY_ASSIGNED');
          }

          final applicantDeveloperId = (applicationData['developerId'] ?? '')
              .toString()
              .trim();

          if (applicantDeveloperId.isEmpty) {
            throw Exception('INVALID_DEVELOPER');
          }

          transaction.update(applicationRef, {
            'status': 'accepted',
            'updatedAt': now,
          });

          final agreedDuration = (applicationData['estimatedDuration'] ?? '')
              .toString()
              .trim();

          if (agreedDuration.isEmpty) {
            throw Exception('MISSING_PROJECT_DURATION');
          }

          transaction.update(projectRef, {
            'developerId': applicantDeveloperId,
            'status': 'active',
            'startedAt': now,
            'duration': agreedDuration,
            'updatedAt': now,
          });
        } else {
          transaction.update(applicationRef, {
            'status': newStatus,
            'updatedAt': now,
          });
        }
      });

      if (context.mounted) {
        _showMessage(
          context,
          newStatus == 'accepted'
              ? 'Developer accepted and project assigned successfully.'
              : 'Application ${_statusLabel(newStatus).toLowerCase()} successfully.',
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      final error = e.toString();

      if (error.contains('PROJECT_ALREADY_ASSIGNED')) {
        _showMessage(
          context,
          'A developer has already been assigned to this project.',
        );
      } else if (error.contains('ACCESS_DENIED') ||
          error.contains('APPLICATION_ACCESS_DENIED')) {
        _showMessage(
          context,
          'You are not authorized to update this application.',
        );
      } else if (error.contains('PROJECT_NOT_FOUND')) {
        _showMessage(context, 'Project not found.');
      } else if (error.contains('APPLICATION_NOT_FOUND')) {
        _showMessage(context, 'Application not found.');
      } else if (error.contains('APPLICATION_ALREADY_PROCESSED')) {
        _showMessage(context, 'This application has already been processed.');
      } else if (error.contains('INVALID_DEVELOPER')) {
        _showMessage(
          context,
          'The application does not contain a valid developer ID.',
        );
      } else {
        debugPrint('Application status update failed: $e');
        _showMessage(
          context,
          'Could not update application. Please check your Firestore rules and try again.',
        );
      }
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmAction(
    BuildContext context,
    String applicationId,
    String status,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Confirm ${_statusLabel(status)}'),
        content: Text(
          'Are you sure you want to ${status == 'shortlisted' ? 'shortlist' : status} this application?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _updateStatus(context, applicationId, status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Applications')),
        body: const Center(child: Text('Please log in to view applications.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        toolbarHeight: 82,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF5F7FB),
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5EAF2)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x070F172A),
                  blurRadius: 18,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                // Back button
                Material(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(13),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Applications icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.assignment_outlined,
                    color: Color(0xFF2563EB),
                    size: 22,
                  ),
                ),

                const SizedBox(width: 12),

                // Title and subtitle
                const Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Applications',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF101828),
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'DEVELOPER APPLICATIONS',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ApplicationsAmbientPainter()),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5EAF2)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x070F172A),
                        blurRadius: 18,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline_rounded,
                            color: colors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              projectTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Review developers who applied to your project.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore
                      .collection('applications')
                      .where('projectId', isEqualTo: projectId)
                      .where('clientId', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, size: 44),
                              const SizedBox(height: 12),
                              const Text(
                                'Could not load applications.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check your internet connection and Firestore rules.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final applications = snapshot.data?.docs ?? [];

                    applications.sort((a, b) {
                      final aTime = a.data()['createdAt'] as Timestamp?;
                      final bTime = b.data()['createdAt'] as Timestamp?;

                      return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(
                        aTime?.millisecondsSinceEpoch ?? 0,
                      );
                    });

                    if (applications.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline_rounded,
                                size: 64,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No applications yet',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Developer applications will appear here when someone applies to this project.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final pendingCount = applications.where((doc) {
                      return (doc.data()['status'] ?? 'pending') == 'pending';
                    }).length;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                          child: Row(
                            children: [
                              Text(
                                '${applications.length} ${applications.length == 1 ? 'Application' : 'Applications'}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '$pendingCount pending',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: applications.length,
                            itemBuilder: (context, index) {
                              final doc = applications[index];
                              final data = doc.data();

                              return _ApplicationCard(
                                applicationId: doc.id,
                                data: data,
                                statusColor: _statusColor(
                                  (data['status'] ?? 'pending').toString(),
                                  colors,
                                ),
                                statusLabel: _statusLabel(
                                  (data['status'] ?? 'pending').toString(),
                                ),
                                onStatusChange: (status) =>
                                    _confirmAction(context, doc.id, status),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final String applicationId;
  final Map<String, dynamic> data;
  final Color statusColor;
  final String statusLabel;
  final ValueChanged<String> onStatusChange;

  const _ApplicationCard({
    required this.applicationId,
    required this.data,
    required this.statusColor,
    required this.statusLabel,
    required this.onStatusChange,
  });

  String _developerName(Map<String, dynamic> userData) {
    return (userData['name'] ??
            userData['fullName'] ??
            userData['displayName'] ??
            'Developer')
        .toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final status = (data['status'] ?? 'pending').toString().toLowerCase();
    final developerId = (data['developerId'] ?? '').toString();

    final budget = data['proposedBudget'];
    final duration = data['estimatedDuration'];
    final coverLetter = (data['coverLetter'] ?? '').toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(21),
        side: const BorderSide(color: Color(0xFFE5EAF2)),
      ),
      shadowColor: const Color(0x070F172A),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: developerId.isEmpty
                      ? _developerIdentity(
                          theme: theme,
                          colors: colors,
                          userData: const {},
                        )
                      : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(developerId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final userData = snapshot.data?.data() ?? {};

                            return _developerIdentity(
                              theme: theme,
                              colors: colors,
                              userData: userData,
                            );
                          },
                        ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _InfoItem(
                    icon: Icons.currency_rupee_rounded,
                    label: 'Proposed Budget',
                    value: budget == null || budget.toString().isEmpty
                        ? 'Not specified'
                        : '₹$budget',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoItem(
                    icon: Icons.schedule_rounded,
                    label: 'Estimated Duration',
                    value: duration == null || duration.toString().isEmpty
                        ? 'Not specified'
                        : duration.toString(),
                  ),
                ),
              ],
            ),
            if (coverLetter.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'Cover Letter',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                coverLetter,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
            if (status == 'pending' || status == 'shortlisted') ...[
              const SizedBox(height: 18),
              Divider(color: colors.outlineVariant),
              const SizedBox(height: 8),
              if (status == 'pending')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => onStatusChange('rejected'),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onStatusChange('shortlisted'),
                        icon: const Icon(Icons.star_outline_rounded),
                        label: const Text('Shortlist'),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onStatusChange('rejected'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colors.error,
                        ),
                        child: const Text('Reject'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => onStatusChange('accepted'),
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Accept'),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _developerIdentity({
    required ThemeData theme,
    required ColorScheme colors,
    required Map<String, dynamic> userData,
  }) {
    final name = _developerName(userData);
    final profileImageUrl =
        userData['profileImageUrl']?.toString().trim() ?? '';

    return Row(
      children: [
        SkillBridgeAvatar(
          profileImageUrl: profileImageUrl,
          name: name,
          size: 50,
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Developer',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5EAF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationsAmbientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x0D2563EB);
    canvas.drawCircle(
      Offset(size.width * 0.88, size.height * 0.10),
      190,
      paint,
    );

    paint.color = const Color(0x087C3AED);
    canvas.drawCircle(
      Offset(size.width * 0.04, size.height * 0.76),
      150,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ApplicationsAmbientPainter oldDelegate) {
    return false;
  }
}
