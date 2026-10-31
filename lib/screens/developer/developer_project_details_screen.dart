import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/developer_note.dart';
import '../client/client_messages_screen.dart';
import '../client/project_meeting_screen.dart';
import 'developer_repositories_screen.dart';
import 'note_editor_screen.dart';
import '../client/client_team_screen.dart';

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

  // ============================================================
  // PROJECT AUTHORIZATION
  // ============================================================

  Future<bool> _isAuthorizedProjectMember(String currentUserId) async {
    if (FirebaseAuth.instance.currentUser?.uid != currentUserId) {
      return false;
    }

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

    // Directly assigned developer.
    if (project['developerId']?.toString() == currentUserId) {
      return true;
    }

    // Check active teams associated with this project.
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

  // ============================================================
  // BUILD
  // ============================================================

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
                  // Project Header
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
                              MaterialPageRoute(
                                builder: (_) =>
                                    ClientTeamScreen(projectId: projectId),
                              ),
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
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => NoteEditorScreen(
                                    initialCategory: DeveloperNote.dailyWork,
                                    projectId: projectId,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.note_add_outlined),
                            label: const Text('Create Project Note'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const DeveloperRepositoriesScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.code_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'GitHub Repositories',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        'Manage your repositories and showcase your projects.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Color(0xFF64748B),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 4. Project Description
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

                  // 6. Project Budget
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

                  // 7. Project Timeline
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

                  // 8. Project Payments
                  // Moved above Project Progress.
                  // Separate Payment Status card removed.
                  _projectPaymentsSection(project),

                  // 9. Project Progress
                  _section(
                    title: 'Project Progress',
                    subtitle:
                        'Complete each milestone to advance your project.',
                    icon: Icons.trending_up_outlined,
                    child: _projectProgressSection(context, project),
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

  // ============================================================
  // PROJECT PAYMENTS
  // ============================================================

  Widget _projectPaymentsSection(Map<String, dynamic> project) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('projectId', isEqualTo: projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _section(
            title: 'Project Payments',
            subtitle: 'Payment summary and transaction history.',
            icon: Icons.account_balance_wallet_outlined,
            child: Text(
              'Unable to load payment records: ${snapshot.error}',
              style: const TextStyle(color: muted, height: 1.5),
            ),
          );
        }

        if (!snapshot.hasData) {
          return _section(
            title: 'Project Payments',
            subtitle: 'Payment summary and transaction history.',
            icon: Icons.account_balance_wallet_outlined,
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: primary),
              ),
            ),
          );
        }

        final payments =
            snapshot.data!.docs.map((doc) {
              return <String, dynamic>{'id': doc.id, ...doc.data()};
            }).toList()..sort((a, b) {
              final dateA = _paymentDate(a);
              final dateB = _paymentDate(b);

              if (dateA == null && dateB == null) {
                return 0;
              }

              if (dateA == null) return 1;
              if (dateB == null) return -1;

              return dateB.compareTo(dateA);
            });

        final budget = _projectBudget(project);

        final totalPaid = payments
            .where(_isSuccessfulPayment)
            .fold<double>(
              0,
              (total, payment) => total + _paymentAmount(payment),
            );

        final remaining = (budget - totalPaid).clamp(0.0, double.infinity);

        final progress = budget > 0
            ? (totalPaid / budget).clamp(0.0, 1.0).toDouble()
            : 0.0;

        return _section(
          title: 'Project Payments',
          subtitle: 'Payment summary and transaction history.',
          icon: Icons.account_balance_wallet_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Budget and total paid.
              Row(
                children: [
                  Expanded(
                    child: _paymentSummary(
                      'Project Budget',
                      _money(budget),
                      primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _paymentSummary(
                      'Total Paid',
                      _money(totalPaid),
                      const Color(0xFF059669),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Remaining amount.
              _paymentSummary(
                'Remaining',
                _money(remaining),
                const Color(0xFFB45309),
              ),

              // Payment progress.
              if (budget > 0) ...[
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payment Progress',
                      style: TextStyle(
                        color: dark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: const TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFEEF2F6),
                    color: primary,
                  ),
                ),
              ],

              const Divider(height: 28),

              // Transaction history.
              Text(
                'Transaction History (${payments.length})',
                style: const TextStyle(
                  color: dark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 10),

              if (payments.isEmpty)
                const Text(
                  'No payment transactions have been recorded for this project yet.',
                  style: TextStyle(color: muted, height: 1.5),
                )
              else
                for (final payment in payments.take(5))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 20,
                          color: primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _string(
                                  payment['paymentId'] ??
                                      payment['razorpayPaymentId'] ??
                                      payment['id'],
                                  fallback: 'Project payment',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: dark,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${_formatPaymentDate(_paymentDate(payment))} · '
                                '${_string(payment['status'], fallback: 'Pending')}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _money(_paymentAmount(payment)),
                          style: const TextStyle(
                            color: dark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),

              const SizedBox(height: 14),

              // Share payment statement.
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _shareProjectPaymentStatement(
                    context: context,
                    project: project,
                    payments: payments,
                    projectBudget: budget,
                    totalPaid: totalPaid,
                    remaining: remaining,
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Share Payment Statement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _paymentSummary(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SHARE PROJECT PAYMENT STATEMENT
  // ============================================================

  Future<void> _shareProjectPaymentStatement({
    required BuildContext context,
    required Map<String, dynamic> project,
    required List<Map<String, dynamic>> payments,
    required double projectBudget,
    required double totalPaid,
    required double remaining,
  }) async {
    try {
      final pdf = pw.Document();
      final title = _string(project['title'], fallback: 'Project');
      final currency = _string(project['currency'], fallback: 'INR');
      final progress = projectBudget > 0
          ? (totalPaid / projectBudget).clamp(0.0, 1.0).toDouble()
          : 0.0;

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
              pw.Text(
                label,
                style: pw.TextStyle(
                  color: PdfColor.fromHex('#64748B'),
                  fontSize: 10,
                ),
              ),
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

      final blue = PdfColor.fromHex('#2563EB');
      final darkPdf = PdfColor.fromHex('#0F172A');
      final grey = PdfColor.fromHex('#64748B');
      final lightBlue = PdfColor.fromHex('#EFF6FF');
      final green = PdfColor.fromHex('#15803D');
      final successfulPayments = payments.where(_isSuccessfulPayment).toList();

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
                color: darkPdf,
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
                    title,
                    style: pw.TextStyle(
                      color: darkPdf,
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
                    money(projectBudget),
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
                    money(remaining),
                    PdfColor.fromHex('#FEF3C7'),
                    PdfColor.fromHex('#B45309'),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: summaryCard(
                    'Successful Payments',
                    '${successfulPayments.length}',
                    PdfColor.fromHex('#F1F5F9'),
                    darkPdf,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),
            pw.Text(
              'PAYMENT PROGRESS',
              style: pw.TextStyle(
                color: darkPdf,
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
                    width: 531 * progress,
                    height: 12,
                    color: green,
                  ),
                ),
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              '${(progress * 100).toStringAsFixed(1)}% paid',
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
            if (payments.isEmpty)
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
                data: payments.map((payment) {
                  final status = _string(
                    payment['status'] ?? payment['paymentStatus'],
                    fallback: 'Pending',
                  );
                  final transactionId = _string(
                    payment['razorpayPaymentId'] ??
                        payment['paymentId'] ??
                        payment['transactionId'] ??
                        payment['id'],
                    fallback: 'N/A',
                  );

                  return [
                    formatDate(_paymentDate(payment)),
                    transactionId.length > 18
                        ? '${transactionId.substring(0, 18)}...'
                        : transactionId,
                    status.toUpperCase(),
                    money(_paymentAmount(payment)),
                  ];
                }).toList(),
                headerDecoration: pw.BoxDecoration(
                  color: darkPdf,
                  borderRadius: pw.BorderRadius.circular(5),
                ),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: pw.TextStyle(color: darkPdf, fontSize: 8),
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
                style: pw.TextStyle(color: darkPdf, fontSize: 9),
              ),
            ),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'SkillBridge_Payment_Statement_$projectId.pdf',
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to create payment statement: $error')),
      );
    }
  }

  // ============================================================
  // PAYMENT HELPERS
  // ============================================================

  static double _projectBudget(Map<String, dynamic> project) {
    final value =
        project['budget'] ??
        project['amount'] ??
        project['projectAmount'] ??
        project['totalBudget'] ??
        project['estimate']?['totalCost'];

    return _numericValue(value);
  }

  static double _paymentAmount(Map<String, dynamic> payment) {
    final value =
        payment['amount'] ??
        payment['paidAmount'] ??
        payment['paid_amount'] ??
        payment['totalAmount'];

    if (value != null) {
      return _numericValue(value);
    }

    final amountInPaise = payment['amountInPaise'];

    return amountInPaise is num ? amountInPaise / 100 : 0;
  }

  static double _numericValue(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString().replaceAll(',', '').trim() ?? '',
        ) ??
        0;
  }

  static bool _isSuccessfulPayment(Map<String, dynamic> payment) {
    final status = (payment['status'] ?? payment['paymentStatus'] ?? '')
        .toString()
        .toLowerCase()
        .trim();

    return const [
      'paid',
      'success',
      'successful',
      'completed',
      'captured',
      'verified',
    ].contains(status);
  }

  static DateTime? _paymentDate(Map<String, dynamic> payment) {
    final value =
        payment['paidAt'] ?? payment['createdAt'] ?? payment['updatedAt'];

    return switch (value) {
      Timestamp date => date.toDate(),
      DateTime date => date,
      String date => DateTime.tryParse(date),
      _ => null,
    };
  }

  static String _formatPaymentDate(DateTime? date) {
    if (date == null) {
      return 'Date unavailable';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // PROJECT PROGRESS
  // ============================================================

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

  // ============================================================
  // COMPLETE MILESTONE
  // ============================================================

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

      final milestoneIndex = milestones.indexWhere(
        (milestone) => milestone['key'] == milestoneKey,
      );

      if (milestoneIndex == -1) {
        return;
      }

      final projectRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId);

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
              throw StateError('Complete ${milestones[i]['title']} first.');
            }
          }

          latestMilestones[milestoneKey] = true;

          final completedCount = milestoneOrder
              .where((key) => latestMilestones[key] == true)
              .length;

          final progress = (completedCount / milestoneOrder.length * 100)
              .round();

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

  // ============================================================
  // PROJECT HEADER
  // ============================================================

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

  // ============================================================
  // REUSABLE SECTION
  // ============================================================

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

  // ============================================================
  // PROJECT BUDGET CARD
  // ============================================================

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

  // ============================================================
  // LIST FIELD
  // ============================================================

  Widget _listField(String title, dynamic value) {
    final values = _toStringList(value);

    if (values.isEmpty) {
      return const SizedBox.shrink();
    }

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
            children: values.map((item) {
              return Container(
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
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFORMATION ROW
  // ============================================================

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

  // ============================================================
  // ACTION BUTTON
  // ============================================================

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

  // ============================================================
  // HEADER CHIP
  // ============================================================

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

  // ============================================================
  // STATUS BADGE
  // ============================================================

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

  // ============================================================
  // MESSAGE
  // ============================================================

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

  // ============================================================
  // GENERAL HELPERS
  // ============================================================

  static String _string(dynamic value, {String fallback = 'Not specified'}) {
    if (value == null) {
      return fallback;
    }

    final result = value.toString().trim();

    return result.isEmpty ? fallback : result;
  }

  static List<String> _toStringList(dynamic value) {
    if (value == null) {
      return [];
    }

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
    if (value == null) {
      return 'Not specified';
    }

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
    if (value == null) {
      return 'Not specified';
    }

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String) {
      date = DateTime.tryParse(value);
    }

    if (date == null) {
      return 'Not specified';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  static String _readable(String value) {
    if (value.isEmpty) {
      return 'Not specified';
    }

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
