import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import 'client_messages_screen.dart';
import 'client_team_screen.dart';
import 'project_meeting_screen.dart';
import 'client_applications_screen.dart';

final GlobalKey _projectEstimateSectionKey = GlobalKey();

class ProjectDetailsScreen extends StatefulWidget {
  final String projectId;

  const ProjectDetailsScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends State<ProjectDetailsScreen> {
  bool _showCompleteEstimate = false;

  String _formatStatus(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context);

    switch (status) {
      case 'requirement':
        return l10n.requirement;
      case 'team_formation':
        return l10n.teamFormation;
      case 'development':
        return l10n.development;
      case 'testing':
        return l10n.testing;
      case 'client_review':
        return l10n.clientReview;
      case 'completed':
        return l10n.completed;
      case 'cancelled':
        return l10n.cancelled;
      default:
        return status;
    }
  }

  String _formatPlanLabel(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'([a-z])([A-Z])'),
          (match) => '${match[1]} ${match[2]}',
        )
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
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

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
                errorBuilder: (_, _, _) => const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTeam(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientTeamScreen(projectId: widget.projectId),
      ),
    );
  }

  void _openMessages(BuildContext context, String projectTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientProjectChat(
          projectId: widget.projectId,
          projectTitle: projectTitle,
        ),
      ),
    );
  }

  void _openMeetings(BuildContext context, String projectTitle) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ProjectMeetingScreen(
          projectId: widget.projectId,
          projectTitle: projectTitle,
        ),
      ),
    );
  }

  void _openEstimate(
    BuildContext context,
    String title,
    Map<String, dynamic> data,
  ) {
    final hasSavedPlan =
        data['plan'] is Map && (data['plan'] as Map).isNotEmpty;
    final hasSavedEstimate =
        data['estimate'] is Map && (data['estimate'] as Map).isNotEmpty;

    if (!hasSavedPlan && !hasSavedEstimate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No saved estimate is available for this project yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _showCompleteEstimate = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final targetContext = _projectEstimateSectionKey.currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
          alignment: 0.08,
        );
      }
    });
  }

  bool _developerHasConfirmed(Map<String, dynamic> data) {
    // Only explicit assignment/acceptance fields count here.
    // A workflow status or a teamId alone is not proof of confirmation.
    const confirmationFields = [
      'assignedDeveloperId',
      'selectedDeveloperId',
      'hiredDeveloperId',
      'acceptedDeveloperId',
      'developerId',
      'confirmedDeveloperId',
      'developerConfirmed',
      'developerAccepted',
      'isDeveloperConfirmed',
      'isDeveloperAccepted',
    ];

    for (final field in confirmationFields) {
      final value = data[field];
      if (value == true) return true;
      if (value is String && value.trim().isNotEmpty) return true;
      if (value is List && value.isNotEmpty) return true;
    }
    return false;
  }

  Future<bool> _hasConfirmedApplication(
    FirebaseFirestore firestore,
    String projectId,
  ) async {
    const collections = ['applications', 'projectApplications'];
    const confirmedStatuses = {
      'accepted',
      'confirmed',
      'hired',
      'approved',
      'developer_confirmed',
      'developer_accepted',
    };

    for (final collectionName in collections) {
      final query = await firestore
          .collection(collectionName)
          .where('projectId', isEqualTo: projectId)
          .get();

      for (final application in query.docs) {
        final applicationData = application.data();
        final status = (applicationData['status'] ?? '')
            .toString()
            .trim()
            .toLowerCase()
            .replaceAll(' ', '_');

        if (confirmedStatuses.contains(status) ||
            applicationData['accepted'] == true ||
            applicationData['confirmed'] == true ||
            applicationData['hired'] == true ||
            applicationData['isAccepted'] == true ||
            applicationData['isConfirmed'] == true) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _deleteProject(
    BuildContext context,
    Map<String, dynamic> data,
    String projectTitle,
  ) async {
    if (_developerHasConfirmed(data)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A developer has already been confirmed for this project. '
            'For safety, this project cannot be deleted.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_forever_outlined,
          color: Color(0xFFDC2626),
          size: 34,
        ),
        title: const Text('Delete project?'),
        content: Text(
          '“$projectTitle” and its project-linked database records will be '
          'deleted. This action cannot be undone. You can delete only before '
          'a developer is confirmed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete project'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final projectRef = firestore.collection('projects').doc(widget.projectId);

      // Re-read the project immediately before deletion so a developer
      // confirmation that happened while the dialog was open blocks deletion.
      final latestSnapshot = await projectRef.get();
      if (!context.mounted) return;

      if (!latestSnapshot.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This project has already been deleted.'),
          ),
        );
        Navigator.of(context).maybePop();
        return;
      }

      final latestData = latestSnapshot.data() ?? <String, dynamic>{};
      final hasConfirmedApplication = await _hasConfirmedApplication(
        firestore,
        widget.projectId,
      );
      if (!context.mounted) return;

      if (_developerHasConfirmed(latestData) || hasConfirmedApplication) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'A developer has now been confirmed. This project cannot be deleted.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Delete project-linked top-level records where projectId is stored.
      // Each batch is kept below Firestore's 500-write limit.
      const relatedCollections = [
        'applications',
        'projectApplications',
        'projectMeetings',
        'meetings',
        'notifications',
      ];

      for (final collectionName in relatedCollections) {
        final query = await firestore
            .collection(collectionName)
            .where('projectId', isEqualTo: widget.projectId)
            .get();

        for (var start = 0; start < query.docs.length; start += 450) {
          final batch = firestore.batch();
          final end = (start + 450 < query.docs.length)
              ? start + 450
              : query.docs.length;
          for (final doc in query.docs.sublist(start, end)) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
      }

      // Delete the parent project document last, after its linked records.
      await projectRef.delete();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Project and linked records deleted successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).maybePop();
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete project: ${error.message ?? error.code}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete project: $error')),
      );
    }
  }

  void _openApplications(BuildContext context, String projectTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientApplicationsScreen(
          projectId: widget.projectId,
          projectTitle: projectTitle,
        ),
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

  String _noDescriptionText(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (languageCode == 'mr') {
      return 'वर्णन उपलब्ध नाही.';
    }

    if (languageCode == 'hi') {
      return 'विवरण उपलब्ध नहीं है।';
    }

    return 'No description provided.';
  }

  String _noRequirementsText(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (languageCode == 'mr') {
      return 'आवश्यकता उपलब्ध नाहीत.';
    }

    if (languageCode == 'hi') {
      return 'कोई आवश्यकताएँ उपलब्ध नहीं हैं।';
    }

    return 'No requirements provided.';
  }

  String _notSpecifiedText(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (languageCode == 'mr') {
      return 'नमूद केलेले नाही';
    }

    if (languageCode == 'hi') {
      return 'निर्दिष्ट नहीं है';
    }

    return 'Not specified';
  }

  String _projectNotFoundText(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (languageCode == 'mr') {
      return 'हा प्रोजेक्ट अस्तित्वात नाही.';
    }

    if (languageCode == 'hi') {
      return 'यह प्रोजेक्ट मौजूद नहीं है।';
    }

    return 'This project does not exist.';
  }

  String _emptyProjectDataText(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (languageCode == 'mr') {
      return 'प्रोजेक्टची माहिती रिकामी आहे.';
    }

    if (languageCode == 'hi') {
      return 'प्रोजेक्ट का डेटा खाली है।';
    }

    return 'Project data is empty.';
  }

  String _teamSubtitle(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (languageCode == 'mr') {
      return 'नियुक्त developers पहा';
    }

    if (languageCode == 'hi') {
      return 'असाइन किए गए developers देखें';
    }

    return 'View assigned developers';
  }

  String _messagesSubtitle(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;

    if (languageCode == 'mr') {
      return 'तुमच्या team सोबत chat करा';
    }

    if (languageCode == 'hi') {
      return 'अपनी team से chat करें';
    }

    return 'Chat with your team';
  }

  String _cleanDescription(String value) {
    var cleaned = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // Remove Markdown emphasis markers while keeping the actual description text.
    cleaned = cleaned.replaceAll('**', '').replaceAll('__', '');
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)'),
      (match) => match.group(1) ?? '',
    );

    // Convert Markdown star bullets to regular bullets instead of showing asterisks.
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'(^|\n)\s*\*\s+'),
      (match) => '${match.group(1)}• ',
    );

    // Remove Markdown heading markers and normalize excessive blank lines.
    cleaned = cleaned.replaceAll(
      RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true),
      '',
    );
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return cleaned.trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    Widget buildEstimateValue(String label, dynamic value, {int depth = 0}) {
      if (value == null) {
        return const SizedBox.shrink();
      }

      if (value is String && value.trim().isEmpty) {
        return const SizedBox.shrink();
      }

      if (value is Map) {
        final entries = value.entries.where((entry) {
          return entry.value != null;
        }).toList();

        if (entries.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(left: depth > 0 ? 12 : 0, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _formatPlanLabel(label),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF344054),
                    ),
                  ),
                ),
              ...entries.map(
                (entry) => buildEstimateValue(
                  entry.key.toString(),
                  entry.value,
                  depth: depth + 1,
                ),
              ),
            ],
          ),
        );
      }

      if (value is List) {
        final items = value.where((item) => item != null).toList();

        if (items.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(left: depth > 0 ? 12 : 0, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _formatPlanLabel(label),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF344054),
                    ),
                  ),
                ),
              ...items.asMap().entries.map((entry) {
                final item = entry.value;

                if (item is Map || item is List) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: buildEstimateValue(
                      item is Map ? '' : 'Item ${entry.key + 1}',
                      item,
                      depth: depth + 1,
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 17,
                        color: Color(0xFF4F46E5),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF475467),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatPlanLabel(label),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFF344054),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),

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

                // Project icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF4FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.folder_copy_rounded,
                    color: Color(0xFF2563EB),
                    size: 21,
                  ),
                ),

                const SizedBox(width: 12),

                // Title and subtitle
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).projectDetails,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF101828),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'PROJECT OVERVIEW',
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
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ProjectDetailsAmbientPainter()),
            ),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('projects')
                .doc(widget.projectId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: _ProjectLoader());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _ProjectErrorCard(
                      message:
                          '${l10n.somethingWentWrong}\n'
                          '${snapshot.error}',
                    ),
                  ),
                );
              }

              final document = snapshot.data;

              if (document == null || !document.exists) {
                return Center(
                  child: Text(
                    _projectNotFoundText(context),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              final data = document.data();

              if (data == null) {
                return Center(
                  child: Text(
                    _emptyProjectDataText(context),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }

              final title = data['title']?.toString() ?? l10n.project;

              final category = data['category']?.toString() ?? '';

              final description = _cleanDescription(
                data['description']?.toString() ?? '',
              );

              final requirements = data['requirements']?.toString() ?? '';

              final plan = data['plan'] is Map
                  ? Map<String, dynamic>.from(data['plan'] as Map)
                  : <String, dynamic>{};

              final estimate = data['estimate'] is Map
                  ? Map<String, dynamic>.from(data['estimate'] as Map)
                  : (plan['estimate'] is Map
                        ? Map<String, dynamic>.from(plan['estimate'] as Map)
                        : <String, dynamic>{});

              String firstValidValue(List<dynamic> values) {
                for (final value in values) {
                  if (value == null) continue;

                  if (value is num && value <= 0) continue;

                  final text = value.toString().trim();
                  if (text.isNotEmpty && text.toLowerCase() != 'null') {
                    return text;
                  }
                }
                return '';
              }

              final budget = firstValidValue([
                data['budget'],
                estimate['totalCost'],
                estimate['totalBudget'],
                estimate['budget'],
                estimate['estimatedCost'],
                estimate['amount'],
              ]);

              final timeline = firstValidValue([
                data['timeline'],
                estimate['timeline'],
                estimate['duration'],
                estimate['estimatedDuration'],
                plan['timeline'],
                plan['duration'],
              ]);
              final status = data['status']?.toString() ?? 'requirement';

              final statusColor = _statusColor(status);
              final designImages = data['designImageUrls'] is List
                  ? (data['designImageUrls'] as List)
                        .whereType<String>()
                        .where((url) => url.startsWith('https://'))
                        .toList()
                  : <String>[];

              return LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth > 900
                      ? 28.0
                      : 20.0;

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      30,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 950),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ProjectHero(
                              title: title,
                              category: category,
                              status: status,
                              statusColor: statusColor,
                              statusIcon: _statusIcon(status),
                              statusText: _formatStatus(context, status),
                            ),
                            if (designImages.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _DetailsCard(
                                title: 'Project Design Images',
                                icon: Icons.image_outlined,
                                child: SizedBox(
                                  height: 190,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: designImages.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final imageUrl = designImages[index];

                                      return GestureDetector(
                                        onTap: () =>
                                            _showFullImage(context, imageUrl),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          child: Image.network(
                                            imageUrl,
                                            width: 250,
                                            height: 190,
                                            fit: BoxFit.cover,
                                            loadingBuilder:
                                                (context, child, progress) {
                                                  if (progress == null) {
                                                    return child;
                                                  }
                                                  return const SizedBox(
                                                    width: 250,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  );
                                                },
                                            errorBuilder: (_, _, _) =>
                                                Container(
                                                  width: 250,
                                                  color: const Color(
                                                    0xFFF1F5F9,
                                                  ),
                                                  child: const Icon(
                                                    Icons.broken_image_outlined,
                                                    size: 40,
                                                  ),
                                                ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            const SizedBox(height: 16),

                            LayoutBuilder(
                              builder: (context, actionConstraints) {
                                final buttons = [
                                  _ActionButton(
                                    icon: Icons.assignment_outlined,
                                    title: 'View Applications',
                                    subtitle: 'Review developer applications',
                                    onTap: () =>
                                        _openApplications(context, title),
                                  ),
                                  _ActionButton(
                                    icon: Icons.groups_outlined,
                                    title: l10n.projectTeam,
                                    subtitle: _teamSubtitle(context),
                                    onTap: () => _openTeam(context),
                                  ),
                                  _ActionButton(
                                    icon: Icons.chat_bubble_outline_rounded,
                                    title: l10n.projectConversation,
                                    subtitle: _messagesSubtitle(context),
                                    onTap: () => _openMessages(context, title),
                                  ),
                                  _ActionButton(
                                    icon: Icons.video_call_rounded,
                                    title: 'Project Meetings',
                                    subtitle: 'Schedule or view team meetings',
                                    onTap: () => _openMeetings(context, title),
                                  ),
                                  _ActionButton(
                                    icon: Icons.calculate_outlined,
                                    title: 'Project Estimate',
                                    subtitle: 'View the saved project plan and estimate',
                                    onTap: () =>
                                        _openEstimate(context, title, data),
                                  ),
                                  _ActionButton(
                                    icon: Icons.delete_outline_rounded,
                                    title: 'Delete Project',
                                    subtitle: _developerHasConfirmed(data)
                                        ? 'Unavailable after developer confirmation'
                                        : 'Delete project before a developer is confirmed',
                                    onTap: () =>
                                        _deleteProject(context, data, title),
                                  ),
                                ];

                                if (actionConstraints.maxWidth > 650) {
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(child: buttons[0]),
                                          const SizedBox(width: 14),
                                          Expanded(child: buttons[1]),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        children: [
                                          Expanded(child: buttons[2]),
                                          const SizedBox(width: 14),
                                          Expanded(child: buttons[3]),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      buttons[4],
                                      const SizedBox(height: 14),
                                      buttons[5],
                                    ],
                                  );
                                }

                                return Column(
                                  children: [
                                    for (
                                      int i = 0;
                                      i < buttons.length;
                                      i++
                                    ) ...[
                                      if (i > 0) const SizedBox(height: 14),
                                      buttons[i],
                                    ],
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 18),

                            _DetailsCard(
                              title: l10n.projectDescription,
                              icon: Icons.description_outlined,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFFF8FAFF),
                                      Color(0xFFF5F7FF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE0E7FF),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0E7FF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.notes_rounded,
                                        size: 18,
                                        color: Color(0xFF4F46E5),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: SelectableText(
                                        description.isEmpty
                                            ? _noDescriptionText(context)
                                            : description,
                                        textAlign: TextAlign.start,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.75,
                                          letterSpacing: 0.1,
                                          color: Color(0xFF344054),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            _DetailsCard(
                              title: l10n.requirements,
                              icon: Icons.checklist_rounded,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFE5EAF2),
                                  ),
                                ),
                                child: SelectableText(
                                  requirements.isEmpty
                                      ? _noRequirementsText(context)
                                      : requirements,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.75,
                                    letterSpacing: 0.1,
                                    color: Color(0xFF344054),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            LayoutBuilder(
                              builder: (context, infoConstraints) {
                                final budgetCard = _InfoCard(
                                  icon: Icons.currency_rupee_rounded,
                                  title: l10n.budget,
                                  value: budget.isEmpty
                                      ? _notSpecifiedText(context)
                                      : budget,
                                );

                                final timelineCard = _InfoCard(
                                  icon: Icons.schedule_outlined,
                                  title: l10n.timeline,
                                  value: timeline.isEmpty
                                      ? _notSpecifiedText(context)
                                      : timeline,
                                );

                                if (infoConstraints.maxWidth < 600) {
                                  return Column(
                                    children: [
                                      budgetCard,
                                      const SizedBox(height: 12),
                                      timelineCard,
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    Expanded(child: budgetCard),
                                    const SizedBox(width: 12),
                                    Expanded(child: timelineCard),
                                  ],
                                );
                              },
                            ),

                            const SizedBox(height: 14),

                            _DetailsCard(
                              title: l10n.progress,
                              icon: Icons.timeline_rounded,
                              child: _ProgressTimeline(
                                currentStatus: status,
                                isStepActive: _isStepActive,
                              ),
                            ),
                            const SizedBox(height: 14),

                            if (_showCompleteEstimate &&
                                (plan.isNotEmpty || estimate.isNotEmpty)) ...[
                              const SizedBox(height: 14),
                              _DetailsCard(
                                key: _projectEstimateSectionKey,
                                title: 'Complete Project Estimate',
                                icon: Icons.analytics_outlined,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (plan['projectSummary'] != null)
                                      buildEstimateValue(
                                        'Project Summary',
                                        plan['projectSummary'],
                                      ),

                                    ...plan.entries
                                        .where(
                                          (entry) =>
                                              entry.key != 'projectSummary' &&
                                              entry.key != 'estimate',
                                        )
                                        .map(
                                          (entry) => buildEstimateValue(
                                            entry.key.toString(),
                                            entry.value,
                                          ),
                                        ),

                                    if (estimate.isNotEmpty) ...[
                                      const Divider(height: 24),
                                      const Text(
                                        'Estimate Details',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      ...estimate.entries.map(
                                        (entry) => buildEstimateValue(
                                          entry.key.toString(),
                                          entry.value,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
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
          colors: [Color(0xFF111827), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 25,
            offset: Offset(0, 9),
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
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
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
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 23,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
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
                _HeroChip(icon: Icons.category_outlined, label: category),
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

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFA5B4FC)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
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
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF4F46E5), size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Color(0xFF4F46E5),
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
    super.key,
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: const Color(0xFF4F46E5)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    letterSpacing: -0.2,
                  ),
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
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
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
  final bool Function(String currentStatus, String step) isStepActive;

  const _ProgressTimeline({
    required this.currentStatus,
    required this.isStepActive,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        _ProgressStep(
          title: l10n.requirement,
          icon: Icons.description_outlined,
          active: isStepActive(currentStatus, 'requirement'),
        ),
        _ProgressStep(
          title: l10n.teamFormation,
          icon: Icons.groups_outlined,
          active: isStepActive(currentStatus, 'team_formation'),
        ),
        _ProgressStep(
          title: l10n.development,
          icon: Icons.code_rounded,
          active: isStepActive(currentStatus, 'development'),
        ),
        _ProgressStep(
          title: l10n.testing,
          icon: Icons.bug_report_outlined,
          active: isStepActive(currentStatus, 'testing'),
        ),
        _ProgressStep(
          title: l10n.clientReview,
          icon: Icons.rate_review_outlined,
          active: isStepActive(currentStatus, 'client_review'),
        ),
        _ProgressStep(
          title: l10n.completed,
          icon: Icons.check_circle_outline_rounded,
          active: isStepActive(currentStatus, 'completed'),
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: active
                      ? const Color(0xFFC7D2FE)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Icon(
                active ? Icons.check_rounded : icon,
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
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFC7D2FE)
                      : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
        const SizedBox(width: 13),
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? const Color(0xFF111827) : const Color(0xFF98A2B3),
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

  const _ProjectErrorCard({required this.message});

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

class _ProjectDetailsAmbientPainter extends CustomPainter {
  const _ProjectDetailsAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0x0A4F46E5);

    canvas.drawCircle(
      Offset(size.width * 0.94, size.height * 0.09),
      190,
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
  bool shouldRepaint(covariant _ProjectDetailsAmbientPainter oldDelegate) {
    return false;
  }
}
