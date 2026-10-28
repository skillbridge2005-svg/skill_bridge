import 'dart:async';

import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'apply_project.dart';

import 'package:skill_bridge/models/project_model.dart';
import 'package:skill_bridge/services/project_service.dart';

import '../../widgets/skillbridge_avatar.dart';

class ProjectDetails extends StatefulWidget {
  const ProjectDetails({
    super.key,
    required this.projectId,
    this.initialProject,
    this.onApply,
  });

  /// Firestore document ID from projects/{projectId}.
  final String projectId;

  /// Optional project already loaded by Discover Projects.
  ///
  /// The screen still listens to Firestore, so the data remains live.
  final ProjectModel? initialProject;

  /// Application flow callback.
  ///
  /// We will connect this to ApplyProject in the next module.
  final VoidCallback? onApply;

  @override
  State<ProjectDetails> createState() => _ProjectDetailsState();
}

class _ProjectDetailsState extends State<ProjectDetails> {
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _background = Color(0xFFF6F8FC);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF667085);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _success = Color(0xFF059669);

  final ProjectService _projectService = ProjectService();

  StreamSubscription<Set<String>>? _savedProjectsSubscription;

  late final Stream<ProjectModel?> _projectStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _paymentsStream;

  ProjectModel? _initialProject;

  Set<String> _savedProjectIds = <String>{};

  List<String> _developerSkills = <String>[];
  List<String> _developerTechnologies = <String>[];

  String? _developerProjectType;
  String? _developerWorkMode;
  String? _developerDuration;

  bool _isSaving = false;
  bool _isProfileLoading = true;
  bool _isSharingStatement = false;

  String? _profileError;

  @override
  void initState() {
    super.initState();

    _initialProject = widget.initialProject;
    _projectStream = _projectService.watchProject(widget.projectId);
    _paymentsStream = FirebaseFirestore.instance
        .collection('payments')
        .where('projectId', isEqualTo: widget.projectId)
        .snapshots();

    _loadDeveloperProfile();
    _listenToSavedProjects();
  }

  @override
  void dispose() {
    _savedProjectsSubscription?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // INITIALIZATION
  // ===========================================================================

  Future<void> _loadDeveloperProfile() async {
    if (!mounted) return;

    setState(() {
      _isProfileLoading = true;
      _profileError = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid == null || uid.trim().isEmpty) {
        throw Exception('No authenticated developer account was found.');
      }

      final profileSnapshot = await FirebaseFirestore.instance
          .collection('developerProfiles')
          .doc(uid)
          .get();

      final userSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      final profileData = profileSnapshot.data() ?? <String, dynamic>{};

      final userData = userSnapshot.data() ?? <String, dynamic>{};

      if (!mounted) return;

      setState(() {
        _developerSkills = _readStringList(profileData['skills']);

        _developerTechnologies = _readStringList(profileData['technologies']);

        _developerProjectType =
            _readString(profileData['projectType']) ??
            _readString(userData['projectType']);

        _developerWorkMode =
            _readString(profileData['workMode']) ??
            _readString(userData['workMode']);

        _developerDuration =
            _readString(profileData['projectDuration']) ??
            _readString(profileData['duration']);

        _isProfileLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isProfileLoading = false;
        _profileError =
            'Your developer preferences could not be loaded. '
            'The project can still be viewed.';
      });
    }
  }

  void _listenToSavedProjects() {
    _savedProjectsSubscription = _projectService.watchSavedProjectIds().listen(
      (ids) {
        if (!mounted) return;

        setState(() {
          _savedProjectIds = ids;
        });
      },
      onError: (_) {
        if (!mounted) return;

        setState(() {
          _savedProjectIds = <String>{};
        });
      },
    );
  }

  // ===========================================================================
  // PROJECT ACTIONS
  // ===========================================================================

  Future<void> _toggleSave(ProjectModel project) async {
    if (_isSaving) return;

    final isSaved = _savedProjectIds.contains(project.id);

    setState(() {
      _isSaving = true;
    });

    try {
      if (isSaved) {
        await _projectService.unsaveProject(project.id);

        _showSnackBar(
          'Project removed from saved projects.',
          icon: Icons.bookmark_border_rounded,
        );
      } else {
        await _projectService.saveProject(project.id);

        _showSnackBar(
          'Project saved successfully.',
          icon: Icons.bookmark_added_rounded,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Unable to update saved project.',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    try {
      await _loadDeveloperProfile();

      await Future<void>.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        _showSnackBar(
          'Project information refreshed.',
          icon: Icons.refresh_rounded,
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          'Unable to refresh project.',
          icon: Icons.error_outline_rounded,
          isError: true,
        );
      }
    }
  }

  void _handleApply(ProjectModel project) {
    if (!project.isOpen) {
      _showSnackBar(
        'This project is no longer accepting applications.',
        icon: Icons.lock_outline_rounded,
        isError: true,
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ApplyProject(projectId: project.id, initialProject: project),
      ),
    );
  }

  Future<void> _shareProject(ProjectModel project) async {
    final shareText =
        '${project.title}\n'
        '${project.description}\n\n'
        'Project ID: ${project.id}';

    try {
      await _copyToClipboard(shareText, message: 'Project information copied.');
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          'Unable to copy project information.',
          icon: Icons.error_outline_rounded,
          isError: true,
        );
      }
    }
  }

  Future<void> _copyToClipboard(
    String value, {
    String message = 'Copied.',
  }) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (!mounted) return;

    _showSnackBar(message, icon: Icons.content_copy_rounded);
  }

  // ===========================================================================
  // PAYMENT STATEMENT (PDF)
  // ===========================================================================

  double _projectTotal(ProjectModel project) {
    final max = project.effectiveBudgetMax;
    final min = project.effectiveBudgetMin;

    if (max > 0) return max;
    if (min > 0) return min;
    return 0;
  }

  Future<void> _sharePaymentStatement(ProjectModel project) async {
    if (_isSharingStatement) return;

    setState(() => _isSharingStatement = true);

    const currency = 'INR';
    final projectTotal = _projectTotal(project);
    final projectTitle = project.title.isEmpty
        ? 'Untitled Project'
        : project.title;
    final projectId = widget.projectId;

    try {
      _showSnackBar(
        'Generating payment statement...',
        icon: Icons.picture_as_pdf_rounded,
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('projectId', isEqualTo: projectId)
          .get();

      final transactions = snapshot.docs.map(_parsePayment).toList()
        ..sort((a, b) {
          if (a.date == null && b.date == null) return 0;
          if (a.date == null) return 1;
          if (b.date == null) return -1;

          return b.date!.compareTo(a.date!);
        });

      final successfulTransactions = transactions
          .where((transaction) => _isSuccessfulStatus(transaction.status))
          .toList();

      final totalPaid = successfulTransactions.fold<double>(
        0,
        (sum, transaction) => sum + transaction.amount,
      );
      final remainingAmount = (projectTotal - totalPaid)
          .clamp(0.0, double.infinity)
          .toDouble();
      final paymentPercentage = projectTotal > 0
          ? (totalPaid / projectTotal).clamp(0.0, 1.0).toDouble()
          : 0.0;

      final pdf = pw.Document();

      final blue = PdfColor.fromHex('#2563EB');
      final dark = PdfColor.fromHex('#0F172A');
      final grey = PdfColor.fromHex('#64748B');
      final lightBlue = PdfColor.fromHex('#EFF6FF');
      final green = PdfColor.fromHex('#15803D');

      String money(double amount) => '$currency ${amount.toStringAsFixed(2)}';

      String formatDate(DateTime? date) {
        if (date == null) return 'N/A';

        final day = date.day.toString().padLeft(2, '0');
        final month = date.month.toString().padLeft(2, '0');
        return '$day/$month/${date.year}';
      }

      pw.Widget summaryCard(
        String label,
        String value,
        PdfColor background,
        PdfColor valueColor,
      ) {
        return pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: background,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label, style: pw.TextStyle(color: grey, fontSize: 10)),
              pw.SizedBox(height: 8),
              pw.Text(
                value,
                style: pw.TextStyle(
                  color: valueColor,
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          footer: (pageContext) => pw.Container(
            margin: const pw.EdgeInsets.only(top: 16),
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'SkillBridge | Payment Statement',
                  style: pw.TextStyle(color: grey, fontSize: 9),
                ),
                pw.Text(
                  'Page ${pageContext.pageNumber} of ${pageContext.pagesCount}',
                  style: pw.TextStyle(color: grey, fontSize: 9),
                ),
              ],
            ),
          ),
          build: (pageContext) => [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(24),
              decoration: pw.BoxDecoration(
                color: dark,
                borderRadius: pw.BorderRadius.circular(16),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SkillBridge',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 25,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'PAYMENT STATEMENT',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 13,
                      letterSpacing: 2,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  pw.Text(
                    'Complete payment overview and transaction history',
                    style: pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'PROJECT DETAILS',
              style: pw.TextStyle(
                color: blue,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: lightBlue,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    projectTitle,
                    style: pw.TextStyle(
                      color: dark,
                      fontSize: 17,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Project ID: $projectId',
                    style: pw.TextStyle(color: grey, fontSize: 9),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    'Generated on: ${formatDate(DateTime.now())}',
                    style: pw.TextStyle(color: grey, fontSize: 9),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'PAYMENT SUMMARY',
              style: pw.TextStyle(
                color: blue,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              children: [
                pw.Expanded(
                  child: summaryCard(
                    'Project Total',
                    money(projectTotal),
                    lightBlue,
                    blue,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: summaryCard(
                    'Total Paid',
                    money(totalPaid),
                    PdfColor.fromHex('#DCFCE7'),
                    green,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              children: [
                pw.Expanded(
                  child: summaryCard(
                    'Remaining',
                    money(remainingAmount),
                    PdfColor.fromHex('#FEF3C7'),
                    PdfColor.fromHex('#B45309'),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: summaryCard(
                    'Successful Payments',
                    '${successfulTransactions.length}',
                    PdfColor.fromHex('#F1F5F9'),
                    dark,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'PAYMENT PROGRESS',
              style: pw.TextStyle(
                color: dark,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.ClipRRect(
              horizontalRadius: 6,
              verticalRadius: 6,
              child: pw.Container(
                height: 12,
                width: double.infinity,
                color: PdfColors.grey200,
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Container(
                    width: 531 * paymentPercentage,
                    height: 12,
                    color: green,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${(paymentPercentage * 100).toStringAsFixed(1)}% paid',
              style: pw.TextStyle(
                color: green,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              'TRANSACTION HISTORY',
              style: pw.TextStyle(
                color: blue,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            if (transactions.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  'No transactions have been recorded for this project.',
                  style: pw.TextStyle(color: grey, fontSize: 10),
                ),
              )
            else
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Transaction ID', 'Status', 'Amount'],
                data: transactions.map((transaction) {
                  final transactionId = transaction.id;

                  return [
                    formatDate(transaction.date),
                    transactionId.length > 18
                        ? '${transactionId.substring(0, 18)}...'
                        : transactionId,
                    transaction.status.toUpperCase(),
                    money(transaction.amount),
                  ];
                }).toList(),
                headerDecoration: pw.BoxDecoration(
                  color: dark,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: pw.TextStyle(color: dark, fontSize: 8),
                cellPadding: const pw.EdgeInsets.all(8),
                border: pw.TableBorder(
                  horizontalInside: pw.BorderSide(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                ),
                oddRowDecoration: pw.BoxDecoration(color: PdfColors.grey100),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.1),
                  1: const pw.FlexColumnWidth(2),
                  2: const pw.FlexColumnWidth(1.3),
                  3: const pw.FlexColumnWidth(1.5),
                },
              ),
            pw.SizedBox(height: 24),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: lightBlue,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Text(
                'Thank you for using SkillBridge. '
                'This statement summarizes the project payment records '
                'available in the system at the time of generation.',
                style: pw.TextStyle(color: dark, fontSize: 9),
              ),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'SkillBridge_Payment_Statement_$projectId.pdf',
      );
    } catch (e) {
      _showSnackBar(
        'Unable to generate payment statement.',
        icon: Icons.error_outline_rounded,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isSharingStatement = false);
      }
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ProjectModel?>(
      stream: _projectStream,
      initialData: _initialProject,
      builder: (context, snapshot) {
        final project = snapshot.data;

        if (project != null) {
          _initialProject = project;
        }

        Widget body;

        if (snapshot.hasError) {
          body = _buildErrorState();
        } else if (snapshot.connectionState == ConnectionState.waiting &&
            project == null) {
          body = _buildLoadingState();
        } else if (project == null) {
          body = _buildNotFoundState();
        } else {
          body = _buildProjectPage(project);
        }

        return Scaffold(
          backgroundColor: _background,
          appBar: _buildAppBar(project),
          body: Stack(
            children: [
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _ProjectDetailsAmbientPainter()),
                ),
              ),
              body,
            ],
          ),
          bottomNavigationBar: project == null || snapshot.hasError
              ? null
              : _buildBottomActionBar(project),
        );
      },
    );
  }

  // ===========================================================================
  // APP BAR (same floating pill as the client screen)
  // ===========================================================================

  PreferredSizeWidget _buildAppBar(ProjectModel? project) {
    final isSaved = project != null && _savedProjectIds.contains(project.id);

    return AppBar(
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
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Project Details',
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
              if (project != null) ...[
                _PillIconButton(
                  icon: Icons.ios_share_rounded,
                  tooltip: 'Share project',
                  onPressed: () => _shareProject(project),
                ),
                const SizedBox(width: 6),
                _PillIconButton(
                  icon: isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  tooltip: isSaved ? 'Remove saved project' : 'Save project',
                  color: isSaved ? _primary : const Color(0xFF475569),
                  onPressed: _isSaving ? null : () => _toggleSave(project),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // PAGE
  // ===========================================================================

  Widget _buildProjectPage(ProjectModel project) {
    final matchPercentage = _matchPercentage(project);

    return RefreshIndicator(
      color: _primary,
      onRefresh: _refresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth > 900 ? 28.0 : 20.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
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
                    _buildHero(project, matchPercentage),
                    const SizedBox(height: 16),
                    _buildQuickStats(project),
                    const SizedBox(height: 16),
                    _buildMatchCard(project, matchPercentage),
                    const SizedBox(height: 14),
                    _buildDescriptionCard(project),
                    const SizedBox(height: 14),
                    _buildSkillsCard(project),
                    const SizedBox(height: 14),
                    _buildTechnologiesCard(project),
                    const SizedBox(height: 14),
                    _buildProjectInfoCard(project),
                    const SizedBox(height: 14),
                    _buildPaymentsSection(project),
                    _buildClientCard(project),
                    const SizedBox(height: 14),
                    _buildActivityCard(project),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // HERO
  // ===========================================================================

  Widget _buildHero(ProjectModel project, int matchPercentage) {
    final open = project.status.trim().toLowerCase() == 'open';
    final statusColor = open
        ? const Color(0xFF34D399)
        : const Color(0xFF9CA3AF);
    final title = project.title.isEmpty ? 'Untitled Project' : project.title;

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
              Hero(
                tag: 'project-${project.id}',
                child: Container(
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
                    Icons.rocket_launch_rounded,
                    color: Color(0xFFA5B4FC),
                    size: 28,
                  ),
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
              _HeroStatusChip(
                icon: open
                    ? Icons.lock_open_rounded
                    : Icons.lock_outline_rounded,
                label: open
                    ? 'Open for applications'
                    : _capitalize(project.status),
                color: statusColor,
              ),
              if (matchPercentage > 0)
                _HeroStatusChip(
                  icon: Icons.auto_awesome_rounded,
                  label: '$matchPercentage% Match',
                  color: const Color(0xFFA5B4FC),
                ),
              if (project.projectType.trim().isNotEmpty)
                _HeroChip(
                  icon: Icons.category_outlined,
                  label: project.projectType.trim(),
                ),
            ],
          ),
          if (project.clientName.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.business_rounded,
                  size: 16,
                  color: Color(0xFFA5B4FC),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Posted by ${project.clientName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStats(ProjectModel project) {
    final budgetCard = _InfoCard(
      icon: Icons.currency_rupee_rounded,
      title: 'Budget',
      value: _budget(project),
    );

    final durationCard = _InfoCard(
      icon: Icons.schedule_outlined,
      title: 'Duration',
      value: _displayValue(project.duration, fallback: 'Flexible'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [budgetCard, const SizedBox(height: 12), durationCard],
          );
        }

        return Row(
          children: [
            Expanded(child: budgetCard),
            const SizedBox(width: 12),
            Expanded(child: durationCard),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // CARDS
  // ===========================================================================

  Widget _buildMatchCard(ProjectModel project, int percentage) {
    final hasProfileData =
        _developerSkills.isNotEmpty ||
        _developerTechnologies.isNotEmpty ||
        _developerProjectType != null ||
        _developerWorkMode != null ||
        _developerDuration != null;

    return _DetailsCard(
      title: 'Your project match',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        children: [
          _MatchCircle(percentage: percentage),
          const SizedBox(height: 16),
          Text(
            _matchMessage(percentage),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _textSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          if (!hasProfileData && !_isProfileLoading) ...[
            const SizedBox(height: 16),
            const _ProfileHint(
              message:
                  'Complete your developer profile to get '
                  'more accurate project recommendations.',
            ),
          ],
          if (_profileError != null) ...[
            const SizedBox(height: 12),
            Text(
              _profileError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(ProjectModel project) {
    final description = project.description.trim();

    return _DetailsCard(
      title: 'About this project',
      icon: Icons.description_outlined,
      child: Text(
        description.isEmpty
            ? 'No project description has been provided yet.'
            : description,
        style: const TextStyle(
          fontSize: 13.5,
          height: 1.65,
          color: Color(0xFF475467),
        ),
      ),
    );
  }

  Widget _buildSkillsCard(ProjectModel project) {
    final skills = project.skills.where((s) => s.trim().isNotEmpty).toList();

    return _DetailsCard(
      title: 'Required skills',
      icon: Icons.psychology_outlined,
      child: skills.isEmpty
          ? const Text(
              'No specific skills have been listed.',
              style: TextStyle(color: _textSecondary, fontSize: 13.5),
            )
          : Wrap(
              spacing: 9,
              runSpacing: 9,
              children: skills
                  .map(
                    (skill) => _TagChip(
                      label: skill,
                      icon: Icons.check_circle_outline_rounded,
                      matched: _developerSkills.any(
                        (s) => s.toLowerCase() == skill.trim().toLowerCase(),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildTechnologiesCard(ProjectModel project) {
    final technologies = project.technologies
        .where((t) => t.trim().isNotEmpty)
        .toList();

    return _DetailsCard(
      title: 'Technologies',
      icon: Icons.code_rounded,
      child: technologies.isEmpty
          ? const Text(
              'No specific technologies have been listed.',
              style: TextStyle(color: _textSecondary, fontSize: 13.5),
            )
          : Wrap(
              spacing: 9,
              runSpacing: 9,
              children: technologies
                  .map(
                    (technology) => _TagChip(
                      label: technology,
                      icon: Icons.code_rounded,
                      matched: _developerTechnologies.any(
                        (t) =>
                            t.toLowerCase() == technology.trim().toLowerCase(),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildProjectInfoCard(ProjectModel project) {
    return _DetailsCard(
      title: 'Project information',
      icon: Icons.tune_rounded,
      child: Column(
        children: [
          _DetailRow(label: 'Budget', value: _budget(project)),
          _DetailRow(
            label: 'Duration',
            value: _displayValue(project.duration, fallback: 'Flexible'),
          ),
          _DetailRow(
            label: 'Project Type',
            value: _displayValue(
              project.projectType,
              fallback: 'Not specified',
            ),
          ),
          _DetailRow(
            label: 'Work Mode',
            value: _displayValue(project.workMode, fallback: 'Flexible'),
          ),
          _DetailRow(
            label: 'Applications',
            value: project.applicationsCount.toString(),
          ),
          _DetailRow(
            label: 'Status',
            value: _capitalize(project.status),
            isLast: true,
          ),
        ],
      ),
    );
  }

  /// Project payments with a "Share Payment Statement" button.
  ///
  /// It only appears once payments exist for this project (and can be read
  /// by the signed-in developer), so open projects without payments do not
  /// show an empty section.
  Widget _buildPaymentsSection(ProjectModel project) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _paymentsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final records = snapshot.data!.docs.map(_parsePayment).toList()
          ..sort((a, b) {
            if (a.date == null && b.date == null) return 0;
            if (a.date == null) return 1;
            if (b.date == null) return -1;

            return b.date!.compareTo(a.date!);
          });

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _ProjectPaymentsCard(
            records: records,
            projectTotal: _projectTotal(project),
            currencySymbol: '₹',
            isSharing: _isSharingStatement,
            onShareStatement: () => _sharePaymentStatement(project),
          ),
        );
      },
    );
  }

  Widget _buildClientCard(ProjectModel project) {
    final clientName = project.clientName.trim();

    return _DetailsCard(
      title: 'About the client',
      icon: Icons.business_center_outlined,
      child: Column(
        children: [
          Row(
            children: [
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: project.clientId.isEmpty
                    ? null
                    : FirebaseFirestore.instance
                          .collection('users')
                          .doc(project.clientId)
                          .snapshots(),
                builder: (context, snapshot) {
                  final client = snapshot.data?.data() ?? {};

                  return SkillBridgeAvatar(
                    profileImageUrl: client['profileImageUrl']?.toString(),
                    name:
                        client['name']?.toString() ??
                        (clientName.isEmpty ? 'Client' : clientName),
                    size: 52,
                    borderRadius: BorderRadius.circular(16),
                    backgroundColor: const Color(0xFFEEF2FF),
                    foregroundColor: _primary,
                  );
                },
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientName.isEmpty ? 'Client' : clientName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.clientId.isEmpty
                          ? 'Client information'
                          : 'Verified account',
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _border),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified_outlined, size: 18, color: _success),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Project posted through SkillBridge',
                    style: TextStyle(
                      color: _textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(ProjectModel project) {
    return _DetailsCard(
      title: 'Project activity',
      icon: Icons.timeline_rounded,
      child: Column(
        children: [
          _TimelineItem(
            icon: Icons.add_circle_outline_rounded,
            title: 'Project posted',
            subtitle: _formatDate(
              project.createdAt,
              fallback: 'Date not available',
            ),
            isFirst: true,
          ),
          _TimelineItem(
            icon: Icons.update_rounded,
            title: 'Last updated',
            subtitle: _formatDate(
              project.updatedAt,
              fallback: project.createdAt != null
                  ? _formatDate(
                      project.createdAt,
                      fallback: 'Date not available',
                    )
                  : 'Not available',
            ),
            isLast: true,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // BOTTOM ACTION BAR
  // ===========================================================================

  Widget _buildBottomActionBar(ProjectModel project) {
    final isSaved = _savedProjectIds.contains(project.id);
    final isOpen = project.isOpen;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 560;

                  final saveButton = OutlinedButton.icon(
                    onPressed: _isSaving ? null : () => _toggleSave(project),
                    icon: Icon(
                      isSaved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      size: 18,
                    ),
                    label: Text(
                      isSaved ? 'Saved' : (compact ? 'Save' : 'Save Project'),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _primary,
                      side: const BorderSide(color: Color(0xFFC7D2FE)),
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  );

                  if (compact) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                isOpen
                                    ? 'Ready to apply?'
                                    : 'Applications are closed',
                                style: const TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            Flexible(
                              child: Text(
                                _budget(project),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  color: _primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: saveButton),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: _ApplyButton(
                                enabled: isOpen,
                                onPressed: () => _handleApply(project),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isOpen
                                  ? 'Interested in this project?'
                                  : 'Applications are currently closed',
                              style: const TextStyle(
                                color: _textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _budget(project),
                              style: const TextStyle(
                                color: _textSecondary,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      saveButton,
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 190,
                        child: _ApplyButton(
                          enabled: isOpen,
                          onPressed: () => _handleApply(project),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // LOADING / ERROR / EMPTY
  // ===========================================================================

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: const Column(
            children: [
              _SkeletonBox(height: 190, radius: 25),
              SizedBox(height: 16),
              _SkeletonBox(height: 80, radius: 19),
              SizedBox(height: 14),
              _SkeletonBox(height: 230, radius: 21),
              SizedBox(height: 14),
              _SkeletonBox(height: 150, radius: 21),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return _CenteredState(
      icon: Icons.cloud_off_rounded,
      title: 'Unable to load project',
      message:
          'Something went wrong while loading this project. '
          'Please check your connection and try again.',
      primaryLabel: 'Retry',
      onPrimary: () {
        setState(() {});
      },
      secondaryLabel: 'Go Back',
      onSecondary: () {
        Navigator.of(context).maybePop();
      },
    );
  }

  Widget _buildNotFoundState() {
    return _CenteredState(
      icon: Icons.search_off_rounded,
      title: 'Project not found',
      message:
          'This project may have been removed, closed, '
          'or is no longer available.',
      primaryLabel: 'Go Back',
      onPrimary: () {
        Navigator.of(context).maybePop();
      },
    );
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  int _matchPercentage(ProjectModel project) {
    if (_isProfileLoading) {
      return 0;
    }

    return project.getMatchPercentage(
      developerSkills: _developerSkills,
      developerTechnologies: _developerTechnologies,
      developerProjectType: _developerProjectType,
      developerWorkMode: _developerWorkMode,
      developerDuration: _developerDuration,
    );
  }

  List<String> _readStringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return <String>[];
  }

  String? _readString(dynamic value) {
    if (value == null) return null;

    final stringValue = value.toString().trim();

    if (stringValue.isEmpty) {
      return null;
    }

    return stringValue;
  }

  String _budget(ProjectModel project) {
    final min = project.effectiveBudgetMin;
    final max = project.effectiveBudgetMax;

    if (min <= 0 && max <= 0) {
      return 'Budget Flexible';
    }

    if (min > 0 && max > 0 && max > min) {
      return '₹${_number(min)} - ₹${_number(max)}';
    }

    final value = max > 0 ? max : min;

    return '₹${_number(value)}';
  }

  /// Compact number without a currency symbol (the caller adds ₹).
  String _number(double value) {
    if (value >= 10000000) {
      return '${(value / 10000000).toStringAsFixed(1)}Cr';
    }

    if (value >= 100000) {
      return '${(value / 100000).toStringAsFixed(1)}L';
    }

    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }

    return value.toStringAsFixed(0);
  }

  String _displayValue(String value, {required String fallback}) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return fallback;
    }

    return trimmed;
  }

  String _formatDate(DateTime? date, {required String fallback}) {
    if (date == null) {
      return fallback;
    }

    final local = date.toLocal();

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

    return '${months[local.month - 1]} '
        '${local.day}, '
        '${local.year}';
  }

  String _matchMessage(int percentage) {
    if (_isProfileLoading) {
      return 'Calculating your compatibility...';
    }

    if (percentage >= 80) {
      return 'Excellent match. This project strongly aligns '
          'with your developer profile.';
    }

    if (percentage >= 60) {
      return 'Strong match. Your profile has several '
          'relevant areas for this project.';
    }

    if (percentage >= 40) {
      return 'Good potential. Consider reviewing the '
          'requirements before applying.';
    }

    if (percentage > 0) {
      return 'Some overlap was found. Review the required '
          'skills carefully.';
    }

    return 'Complete your profile to receive a more '
        'personalized match score.';
  }

  void _showSnackBar(
    String message, {
    required IconData icon,
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFB91C1C)
              : const Color(0xFF111827),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 19),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

// =============================================================================
// DETAILS CARD (same as the client screen)
// =============================================================================

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _ProjectDetailsState._border),
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
                child: Icon(
                  icon,
                  size: 19,
                  color: _ProjectDetailsState._primary,
                ),
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

// =============================================================================
// INFO CARD (budget / duration)
// =============================================================================

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _ProjectDetailsState._border),
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
            child: Icon(icon, size: 20, color: _ProjectDetailsState._primary),
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

// =============================================================================
// DETAIL ROW
// =============================================================================

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF667085),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFF344054),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HERO CHIPS
// =============================================================================

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

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
  const _HeroStatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

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

// =============================================================================
// TAG CHIP (skills / technologies, highlights ones you already have)
// =============================================================================

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.icon,
    required this.matched,
  });

  final String label;
  final IconData icon;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    final color = matched
        ? const Color(0xFF059669)
        : _ProjectDetailsState._textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: matched ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: matched
              ? const Color(0xFFA7F3D0)
              : _ProjectDetailsState._border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            matched ? Icons.check_circle_rounded : icon,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: matched
                  ? const Color(0xFF065F46)
                  : _ProjectDetailsState._textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MATCH CIRCLE
// =============================================================================

class _MatchCircle extends StatelessWidget {
  const _MatchCircle({required this.percentage});

  final int percentage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const SizedBox(
            width: 140,
            height: 140,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 10,
              color: Color(0xFFE5E7EB),
            ),
          ),
          SizedBox(
            width: 140,
            height: 140,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: percentage / 100),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 10,
                  strokeCap: StrokeCap.round,
                  color: _ProjectDetailsState._primary,
                );
              },
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: _ProjectDetailsState._textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const Text(
                'match',
                style: TextStyle(
                  color: _ProjectDetailsState._textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
// TIMELINE
// =============================================================================

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 70,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: _ProjectDetailsState._border,
                    ),
                  ),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _ProjectDetailsState._primary.withValues(
                      alpha: 0.10,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 14,
                    color: _ProjectDetailsState._primary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: _ProjectDetailsState._border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _ProjectDetailsState._textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _ProjectDetailsState._textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PROFILE HINT
// =============================================================================

class _ProfileHint extends StatelessWidget {
  const _ProfileHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9E5FF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: _ProjectDetailsState._primary,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _ProjectDetailsState._textSecondary,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// APPLY BUTTON
// =============================================================================

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          enabled ? Icons.send_rounded : Icons.lock_outline_rounded,
          size: 18,
        ),
        label: Text(
          enabled ? 'Apply Now' : 'Applications Closed',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _ProjectDetailsState._primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE5E7EB),
          disabledForegroundColor: const Color(0xFF9CA3AF),
          elevation: enabled ? 5 : 0,
          shadowColor: _ProjectDetailsState._primary.withValues(alpha: 0.25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SMALL ICON BUTTON INSIDE THE APP BAR PILL
// =============================================================================

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = const Color(0xFF475569),
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: onPressed,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: const Color(0xFFE5EAF2)),
            ),
            child: Icon(
              icon,
              size: 20,
              color: onPressed == null ? const Color(0xFFD1D5DB) : color,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SKELETON
// =============================================================================

class _SkeletonBox extends StatefulWidget {
  const _SkeletonBox({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = 0.06 + (_controller.value * 0.05);

        return Container(
          width: double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.fromRGBO(229, 231, 235, value + 0.10),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

// =============================================================================
// CENTERED STATE
// =============================================================================

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: _ProjectDetailsState._primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, color: _ProjectDetailsState._primary, size: 38),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ProjectDetailsState._textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ProjectDetailsState._textSecondary,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  onPressed: onPrimary,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: Text(primaryLabel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ProjectDetailsState._primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                ),
                if (secondaryLabel != null && onSecondary != null)
                  OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(secondaryLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// BACKGROUND AMBIENT PAINTER
// =============================================================================

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

// =============================================================================
// PAYMENT HELPERS
// =============================================================================

class _PaymentRecord {
  const _PaymentRecord({
    required this.id,
    required this.amount,
    required this.status,
    required this.date,
  });

  final String id;
  final double amount;
  final String status;
  final DateTime? date;
}

_PaymentRecord _parsePayment(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();

  final status = (data['status'] ?? data['paymentStatus'] ?? 'pending')
      .toString()
      .toLowerCase()
      .trim();

  final rawAmount =
      data['amount'] ??
      data['paidAmount'] ??
      data['paid_amount'] ??
      (data['amountInPaise'] is num ? (data['amountInPaise'] as num) / 100 : 0);

  final amount = rawAmount is num
      ? rawAmount.toDouble()
      : double.tryParse(rawAmount.toString().replaceAll(',', '').trim()) ?? 0.0;

  final dateValue = data['paidAt'] ?? data['createdAt'] ?? data['updatedAt'];

  final DateTime? date = switch (dateValue) {
    Timestamp value => value.toDate(),
    DateTime value => value,
    String value => DateTime.tryParse(value),
    _ => null,
  };

  return _PaymentRecord(
    id:
        (data['razorpayPaymentId'] ??
                data['paymentId'] ??
                data['transactionId'] ??
                doc.id)
            .toString(),
    amount: amount,
    status: status,
    date: date,
  );
}

bool _isSuccessfulStatus(String status) {
  return const [
    'paid',
    'success',
    'successful',
    'completed',
    'captured',
    'verified',
  ].contains(status);
}

/// Formats with Indian digit grouping, e.g. 1234567 -> 12,34,567
String _formatInr(double value) {
  final isWhole = value == value.roundToDouble();
  final text = isWhole ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  final parts = text.split('.');
  final digits = parts.first;

  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final last3 = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final chunks = <String>[];
    while (rest.length > 2) {
      chunks.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) chunks.insert(0, rest);
    grouped = '${chunks.join(',')},$last3';
  }

  return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
}

String _shortDate(DateTime? date) {
  if (date == null) return 'Date not available';

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
  final local = date.toLocal();

  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

// =============================================================================
// PROJECT PAYMENTS CARD (read-only, with statement sharing)
// =============================================================================

class _ProjectPaymentsCard extends StatelessWidget {
  const _ProjectPaymentsCard({
    required this.records,
    required this.projectTotal,
    required this.currencySymbol,
    required this.isSharing,
    required this.onShareStatement,
  });

  final List<_PaymentRecord> records;
  final double projectTotal;
  final String currencySymbol;
  final bool isSharing;
  final VoidCallback onShareStatement;

  static const Color _green = Color(0xFF059669);
  static const Color _amber = Color(0xFFB45309);

  String _money(double value) => '$currencySymbol${_formatInr(value)}';

  Color _statusColor(String status) {
    if (_isSuccessfulStatus(status)) return _green;

    switch (status) {
      case 'pending':
        return _amber;
      case 'failed':
        return const Color(0xFFD64545);
      case 'refunded':
        return const Color(0xFF6B46C1);
      default:
        return const Color(0xFF718096);
    }
  }

  IconData _statusIcon(String status) {
    if (_isSuccessfulStatus(status)) return Icons.check_circle_rounded;

    switch (status) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'failed':
        return Icons.error_rounded;
      case 'refunded':
        return Icons.replay_circle_filled_rounded;
      default:
        return Icons.cancel_rounded;
    }
  }

  String _statusLabel(String status) {
    if (_isSuccessfulStatus(status)) return 'Paid';
    if (status.isEmpty) return 'Unknown';

    return status[0].toUpperCase() + status.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final paid = records
        .where((r) => _isSuccessfulStatus(r.status))
        .fold<double>(0, (sum, r) => sum + r.amount);
    final remaining = (projectTotal - paid).clamp(0.0, double.infinity);
    final ratio = projectTotal > 0
        ? (paid / projectTotal).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final visible = records.take(5).toList();

    return _DetailsCard(
      title: 'Project Payments',
      icon: Icons.account_balance_wallet_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (projectTotal > 0) ...[
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Payment progress',
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${(ratio * 100).round()}%',
                  style: const TextStyle(
                    color: _ProjectDetailsState._primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: ratio),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFE5E7EB),
                  color: ratio >= 1 ? _green : _ProjectDetailsState._primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = [
                _PaymentStat(
                  label: 'Project Total',
                  value: projectTotal > 0 ? _money(projectTotal) : 'Not set',
                  color: _ProjectDetailsState._primary,
                ),
                _PaymentStat(
                  label: 'Total Paid',
                  value: _money(paid),
                  color: _green,
                ),
                _PaymentStat(
                  label: 'Remaining',
                  value: projectTotal > 0 ? _money(remaining) : '—',
                  color: _amber,
                ),
              ];

              if (constraints.maxWidth < 420) {
                return Column(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(height: 10),
                      tiles[i],
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  for (var i = 0; i < tiles.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: tiles[i]),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent transactions',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${records.length} total',
                style: const TextStyle(
                  color: _ProjectDetailsState._textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final record in visible)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _ProjectDetailsState._border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _statusColor(record.status)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _statusIcon(record.status),
                      size: 19,
                      color: _statusColor(record.status),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.id.length > 20
                              ? '${record.id.substring(0, 20)}...'
                              : record.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _shortDate(record.date),
                          style: const TextStyle(
                            color: _ProjectDetailsState._textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _money(record.amount),
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _statusLabel(record.status),
                        style: TextStyle(
                          color: _statusColor(record.status),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (records.length > visible.length)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                '+ ${records.length - visible.length} more in the statement',
                style: const TextStyle(
                  color: _ProjectDetailsState._textSecondary,
                  fontSize: 11.5,
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSharing ? null : onShareStatement,
              icon: isSharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(
                isSharing ? 'Generating...' : 'Share Payment Statement',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF93B4F5),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStat extends StatelessWidget {
  const _PaymentStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _ProjectDetailsState._textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PRIVATE HELPERS
// =============================================================================

String _capitalize(String value) {
  final trimmed = value.trim();

  if (trimmed.isEmpty) {
    return 'Unavailable';
  }

  return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
}
