import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

    try {
      // Verify that the current client owns this project.
      final projectDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .get();

      if (!projectDoc.exists || projectDoc.data()?['clientId'] != user.uid) {
        if (context.mounted) {
          _showMessage(context, 'You cannot update this application.');
        }
        return;
      }

      // Verify that the application belongs to this project and client.
      final applicationDoc = await _firestore
          .collection('applications')
          .doc(applicationId)
          .get();

      final application = applicationDoc.data();

      if (!applicationDoc.exists ||
          application == null ||
          application['projectId'] != projectId ||
          application['clientId'] != user.uid) {
        if (context.mounted) {
          _showMessage(context, 'Application not found or access denied.');
        }
        return;
      }

      await applicationDoc.reference.update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        _showMessage(
          context,
          'Application ${_statusLabel(newStatus).toLowerCase()} successfully.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showMessage(
          context,
          'Could not update application. Please try again.',
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
        title: const Text('Applications'),
        centerTitle: false,
        backgroundColor: const Color(0xF7FFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
                CircleAvatar(
                  radius: 25,
                  backgroundColor: colors.primaryContainer,
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: colors.onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: developerId.isEmpty
                      ? Text(
                          'Developer',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(developerId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final userData = snapshot.data?.data() ?? {};

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _developerName(userData),
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
