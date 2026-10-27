import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import 'project_details_screen.dart';

class MyProjectsScreen extends StatelessWidget {
  const MyProjectsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        body: Center(
          child: Text(
            l10n.loginAgain,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ProjectsAmbientPainter()),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .where('clientId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: _ProjectsLoader());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _ProjectsErrorCard(
                      message: '${l10n.somethingWentWrong}\n${snapshot.error}',
                    ),
                  ),
                );
              }
              final projects = snapshot.data?.docs ?? [];
              if (projects.isEmpty) {
                return const _EmptyProjects();
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth > 800
                      ? 28.0
                      : 20.0;
                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      30,
                    ),
                    itemCount: projects.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ProjectsHeader(projectCount: projects.length);
                      }
                      final project = projects[index - 1].data();
                      return _ProjectCard(
                        project: project,
                        projectId: projects[index - 1].id,
                      );
                    },
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

class _ProjectsHeader extends StatelessWidget {
  final int projectCount;
  const _ProjectsHeader({required this.projectCount});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 24,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: const Icon(
              Icons.folder_copy_rounded,
              color: Color(0xFFA5B4FC),
              size: 27,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.myProjects.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: Color(0xFFA5B4FC),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  l10n.myProjects,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.latestProjectActivity,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Color(0xFFD1D5DB),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            ),
            child: Text(
              '$projectCount',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final String projectId;

  const _ProjectCard({required this.project, required this.projectId});

  Future<void> _deleteProject(BuildContext context, String title) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again to delete this project.'),
        ),
      );
      return;
    }
    if (project['status']?.toString() != 'team_formation') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A project can only be deleted during team formation.'),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete project?'),
        content: Text(
          '“$title” will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final projectRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId);
      final latestSnapshot = await projectRef.get();
      if (!latestSnapshot.exists) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This project no longer exists.')),
        );
        return;
      }
      final latestProject = latestSnapshot.data() ?? <String, dynamic>{};
      if (latestProject['clientId']?.toString() != currentUser.uid ||
          latestProject['status']?.toString() != 'team_formation') {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Only your projects in the team formation phase can be deleted.',
            ),
          ),
        );
        return;
      }
      await projectRef.delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project deleted successfully.')),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete project: ${error.message ?? error.code}',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong while deleting the project.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rawTitle = project['title']?.toString().trim() ?? '';
    final title = rawTitle.isEmpty ? l10n.project : rawTitle;
    final milestones = project['milestones'] is Map
        ? Map<String, dynamic>.from(project['milestones'] as Map)
        : <String, dynamic>{};
    const milestoneKeys = <String>[
      'requirements',
      'architecture',
      'design',
      'development',
      'testing',
      'deployment',
    ];

    final completedMilestones = milestoneKeys
        .where((key) => milestones[key] == true)
        .length;
    final progress = (completedMilestones / milestoneKeys.length * 100).round();
    final isCompleted = progress == 100;
    final progressColor = isCompleted
        ? const Color(0xFF16A34A)
        : const Color(0xFF4F46E5);
    final storedStatus = project['status']?.toString() ?? 'requirement';
    // Keep the original rule: a fully completed project is not deletable
    // from this list even if its stored status still says team_formation.
    final effectiveStatus = progress == 100 ? 'completed' : storedStatus;
    final canDelete = effectiveStatus == 'team_formation';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ProjectDetailsScreen(projectId: projectId),
            ),
          );
        },
        // Preserve the existing delete capability without adding extra
        // visible controls to this simplified project list card.
        onLongPress: canDelete ? () => _deleteProject(context, title) : null,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isCompleted
                  ? const Color(0xFFBBF7D0)
                  : const Color(0xFFE5E7EB),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 20,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCompleted
                            ? const [Color(0xFFDCFCE7), Color(0xFFF0FDF4)]
                            : const [Color(0xFFE0E7FF), Color(0xFFF5F3FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      isCompleted
                          ? Icons.task_alt_rounded
                          : Icons.folder_copy_rounded,
                      color: progressColor,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: progressColor.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$progress%',
                      style: TextStyle(
                        color: progressColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 19),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'PROJECT PROGRESS',
                      style: TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  Text(
                    isCompleted
                        ? 'Completed'
                        : '$completedMilestones/${milestoneKeys.length} milestones',
                    style: TextStyle(
                      color: progressColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: LinearProgressIndicator(
                  value: progress / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFEEF2F7),
                  color: progressColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x060F172A),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  size: 39,
                  color: Color(0xFF4F46E5),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.noProjectsYet,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.createFirstProject,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectsLoader extends StatelessWidget {
  const _ProjectsLoader();
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

class _ProjectsErrorCard extends StatelessWidget {
  final String message;
  const _ProjectsErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 500),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEB),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1C2),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFD97706),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectsAmbientPainter extends CustomPainter {
  const _ProjectsAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x0A4F46E5);

    canvas.drawCircle(
      Offset(size.width * 0.94, size.height * 0.09),
      185,
      paint,
    );

    paint.color = const Color(0x087C3AED);

    canvas.drawCircle(
      Offset(size.width * 0.04, size.height * 0.84),
      150,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProjectsAmbientPainter oldDelegate) {
    return false;
  }
}
