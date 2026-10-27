import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../localization/app_localizations.dart';
import 'client_messages_screen.dart';
import 'client_team_screen.dart';
import 'client_applications_screen.dart';
import 'developer_review_widget.dart';
import 'project_meeting_screen.dart';
import 'widgets/project_payment_card.dart';

class ProjectDetailsScreen extends StatelessWidget {
  final String projectId;

  const ProjectDetailsScreen({super.key, required this.projectId});

  // ------------------------------------------------------------
  // STATUS HELPERS
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // NAVIGATION
  // ------------------------------------------------------------

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

  void _openApplications(BuildContext context, String projectTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientApplicationsScreen(
          projectId: projectId,
          projectTitle: projectTitle,
        ),
      ),
    );
  }

  void _openMeetings(BuildContext context, String projectTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectMeetingScreen(
          projectId: projectId,
          projectTitle: projectTitle,
        ),
      ),
    );
  }

  Future<void> _downloadPaymentReceipt({
    required BuildContext context,
    required String projectTitle,
    required double projectTotal,
    required String currency,
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating payment statement...')),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('payments')
          .where('projectId', isEqualTo: projectId)
          .get();

      final transactions = snapshot.docs.map((doc) {
        final data = doc.data();
        final status = (data['status'] ?? data['paymentStatus'] ?? 'pending')
            .toString()
            .toLowerCase()
            .trim();

        final rawAmount =
            data['amount'] ??
            data['paidAmount'] ??
            data['paid_amount'] ??
            (data['amountInPaise'] is num
                ? (data['amountInPaise'] as num) / 100
                : 0);
        final amount = rawAmount is num
            ? rawAmount.toDouble()
            : double.tryParse(
                    rawAmount.toString().replaceAll(',', '').trim(),
                  ) ??
                  0.0;

        final dateValue =
            data['paidAt'] ?? data['createdAt'] ?? data['updatedAt'];
        final DateTime? date = switch (dateValue) {
          Timestamp value => value.toDate(),
          DateTime value => value,
          String value => DateTime.tryParse(value),
          _ => null,
        };

        return <String, Object?>{
          'id':
              (data['razorpayPaymentId'] ??
                      data['paymentId'] ??
                      data['transactionId'] ??
                      doc.id)
                  .toString(),
          'amount': amount,
          'status': status,
          'date': date,
        };
      }).toList();

      transactions.sort((a, b) {
        final dateA = a['date'] as DateTime?;
        final dateB = b['date'] as DateTime?;

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateB.compareTo(dateA);
      });

      bool isSuccessful(String status) {
        return [
          'paid',
          'success',
          'successful',
          'completed',
          'captured',
          'verified',
        ].contains(status);
      }

      final successfulTransactions = transactions.where((transaction) {
        return isSuccessful(transaction['status'] as String);
      }).toList();

      final totalPaid = successfulTransactions.fold<double>(
        0,
        (sum, transaction) => sum + (transaction['amount'] as double),
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
                  final status = transaction['status'] as String;
                  final transactionId = transaction['id'] as String;

                  return [
                    formatDate(transaction['date'] as DateTime?),
                    transactionId.length > 18
                        ? '${transactionId.substring(0, 18)}...'
                        : transactionId,
                    status.toUpperCase(),
                    money(transaction['amount'] as double),
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
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to generate payment statement: $e')),
      );
    }
  }

  // ------------------------------------------------------------
  // LOCALIZED FALLBACK TEXT
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // IMAGE PREVIEW
  // ------------------------------------------------------------

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
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
                    if (progress == null) {
                      return child;
                    }

                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, _, _) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white,
                        size: 48,
                      ),
                    );
                  },
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
        );
      },
    );
  }

  // ------------------------------------------------------------
  // VALUE HELPERS
  // ------------------------------------------------------------

  String _firstValidValue(List<dynamic> values) {
    for (final value in values) {
      if (value == null) continue;

      if (value is num && value <= 0) {
        continue;
      }

      final text = value.toString().trim();

      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }

    return '';
  }

  double _parseProjectAmount(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(
            value.replaceAll(',', '').replaceAll('₹', '').trim(),
          ) ??
          0.0;
    }

    return 0.0;
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  List<String> _stringList(dynamic value) {
    if (value is! List) {
      return <String>[];
    }

    return value
        .where((item) => item != null)
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }

  // ------------------------------------------------------------
  // MAIN SCREEN
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),

      // --------------------------------------------------------
      // CUSTOM APP BAR
      // --------------------------------------------------------
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

                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.projectDetails,
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

      // --------------------------------------------------------
      // FIRESTORE PROJECT STREAM
      // --------------------------------------------------------
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
                .doc(projectId)
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

              // ------------------------------------------------
              // PROJECT DATA
              // ------------------------------------------------

              final title = data['title']?.toString() ?? l10n.project;

              // Support both category and categories.
              final categories = _stringList(data['categories']);

              final category = _firstValidValue([
                data['category'],
                if (categories.isNotEmpty) categories.join(', '),
              ]);

              final description = data['description']?.toString() ?? '';

              final requirements = data['requirements']?.toString() ?? '';

              final plan = _mapValue(data['plan']);

              final planEstimate = _mapValue(plan['estimate']);

              final directEstimate = _mapValue(data['estimate']);

              final estimate = directEstimate.isNotEmpty
                  ? directEstimate
                  : planEstimate;

              // Support manually entered and AI-generated budgets.
              final budget = _firstValidValue([
                data['budget'],
                data['amount'],
                estimate['totalCost'],
                estimate['totalBudget'],
                estimate['budget'],
                estimate['estimatedCost'],
                estimate['amount'],
              ]);

              // Support both timeline and estimatedDuration.
              final timeline = _firstValidValue([
                data['timeline'],
                data['estimatedDuration'],
                estimate['timeline'],
                estimate['duration'],
                estimate['estimatedDuration'],
                plan['timeline'],
                plan['duration'],
              ]);

              final budgetType = data['budgetType']?.toString() ?? '';

              final currency = data['currency']?.toString() ?? 'INR';

              final deadline = data['deadline'];

              final deadlineText = deadline is Timestamp
                  ? '${deadline.toDate().day.toString().padLeft(2, '0')}/'
                        '${deadline.toDate().month.toString().padLeft(2, '0')}/'
                        '${deadline.toDate().year}'
                  : '';

              final experienceLevel = data['experienceLevel']?.toString() ?? '';

              final workMode = data['workMode']?.toString() ?? '';

              final priority = data['priority']?.toString() ?? '';

              final additionalInfo = data['additionalInfo']?.toString() ?? '';

              final status = data['status']?.toString() ?? 'requirement';

              final statusColor = _statusColor(status);
              final milestones = data['milestones'] is Map
                  ? Map<String, dynamic>.from(data['milestones'] as Map)
                  : <String, dynamic>{};
              const milestoneKeys = [
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
              final calculatedProgress =
                  (completedMilestones / milestoneKeys.length * 100).round();
              final isCompleted =
                  calculatedProgress == 100 ||
                  status.trim().toLowerCase() == 'completed';

              final designImages = _stringList(data['designImageUrls'])
                  .where((url) => url.startsWith('https://'))
                  .toList();

              final acceptedScope = _stringList(data['acceptedScope']);

              final acceptedCost = data['acceptedCost'] == true;

              final acceptedTimeline = data['acceptedTimeline'] == true;

              final acceptedTerms = data['acceptedTerms'] == true;

              // ------------------------------------------------
              // RESPONSIVE PAGE
              // ------------------------------------------------

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
                            // ------------------------------------
                            // PROJECT HEADER
                            // ------------------------------------

                            _ProjectHero(
                              title: title,
                              category: category,
                              status: status,
                              statusColor: statusColor,
                              statusIcon: _statusIcon(status),
                              statusText: _formatStatus(context, status),
                            ),
                            if (isCompleted) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Project Completed',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ------------------------------------
                            // DESIGN IMAGES
                            // ------------------------------------
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
                                            errorBuilder: (_, _, _) {
                                              return Container(
                                                width: 250,
                                                color: const Color(0xFFF1F5F9),
                                                child: const Icon(
                                                  Icons.broken_image_outlined,
                                                  size: 40,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // ------------------------------------
                            // ACTION BUTTONS
                            // ------------------------------------
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
                                    title: 'Schedule Meeting',
                                    subtitle: 'Plan a meeting with your team',
                                    onTap: () => _openMeetings(context, title),
                                  ),
                                ];

                                if (actionConstraints.maxWidth > 900) {
                                  return Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: buttons[0]),
                                          const SizedBox(width: 14),
                                          Expanded(child: buttons[1]),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: buttons[2]),
                                          const SizedBox(width: 14),
                                          Expanded(child: buttons[3]),
                                        ],
                                      ),
                                    ],
                                  );
                                }

                                if (actionConstraints.maxWidth > 650) {
                                  return Column(
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: buttons[0]),
                                          const SizedBox(width: 14),
                                          Expanded(child: buttons[1]),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: buttons[2]),
                                          const SizedBox(width: 14),
                                          Expanded(child: buttons[3]),
                                        ],
                                      ),
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

                            ProjectPaymentCard(
                              projectId: projectId,
                              projectTotal: _parseProjectAmount(
                                _firstValidValue([
                                  data['budget'],
                                  data['amount'],
                                  data['projectAmount'],
                                  data['estimate']?['totalCost'],
                                  data['estimate']?['totalBudget'],
                                  data['estimate']?['budget'],
                                  data['estimate']?['estimatedCost'],
                                  data['estimate']?['amount'],
                                ]),
                              ),
                              currency: data['currency']?.toString() ?? 'INR',
                            ),

                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _downloadPaymentReceipt(
                                  context: context,
                                  projectTitle: title,
                                  projectTotal: _parseProjectAmount(
                                    _firstValidValue([
                                      data['budget'],
                                      data['amount'],
                                      data['projectAmount'],
                                      data['estimate']?['totalCost'],
                                      data['estimate']?['totalBudget'],
                                      data['estimate']?['budget'],
                                      data['estimate']?['estimatedCost'],
                                      data['estimate']?['amount'],
                                    ]),
                                  ),
                                  currency:
                                      data['currency']?.toString() ?? 'INR',
                                ),
                                icon: const Icon(Icons.picture_as_pdf_rounded),
                                label: const Text('Share Payment Statement'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // ------------------------------------
                            // DESCRIPTION
                            // ------------------------------------
                            _DetailsCard(
                              title: l10n.projectDescription,
                              icon: Icons.description_outlined,
                              child: Text(
                                description.isEmpty
                                    ? _noDescriptionText(context)
                                    : description,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.65,
                                  color: Color(0xFF475467),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ------------------------------------
                            // REQUIREMENTS
                            // ------------------------------------
                            _DetailsCard(
                              title: l10n.requirements,
                              icon: Icons.checklist_rounded,
                              child: Text(
                                requirements.isEmpty
                                    ? _noRequirementsText(context)
                                    : requirements,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.65,
                                  color: Color(0xFF475467),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ------------------------------------
                            // BUDGET AND TIMELINE
                            // ------------------------------------
                            LayoutBuilder(
                              builder: (context, infoConstraints) {
                                final budgetDisplay = budget.isEmpty
                                    ? _notSpecifiedText(context)
                                    : '$currency $budget';

                                final budgetCard = _InfoCard(
                                  icon: Icons.currency_rupee_rounded,
                                  title: l10n.budget,
                                  value: budgetDisplay,
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

                            // ------------------------------------
                            // ADDITIONAL PROJECT DETAILS
                            // ------------------------------------
                            if (budgetType.isNotEmpty ||
                                deadlineText.isNotEmpty ||
                                experienceLevel.isNotEmpty ||
                                workMode.isNotEmpty ||
                                priority.isNotEmpty ||
                                additionalInfo.isNotEmpty) ...[
                              const SizedBox(height: 14),

                              _DetailsCard(
                                title: 'Additional Project Details',
                                icon: Icons.tune_rounded,
                                child: Column(
                                  children: [
                                    if (budgetType.isNotEmpty)
                                      _DetailRow(
                                        label: 'Payment Type',
                                        value: budgetType,
                                      ),

                                    if (deadlineText.isNotEmpty)
                                      _DetailRow(
                                        label: 'Deadline',
                                        value: deadlineText,
                                      ),

                                    if (experienceLevel.isNotEmpty)
                                      _DetailRow(
                                        label: 'Experience Level',
                                        value: experienceLevel,
                                      ),

                                    if (workMode.isNotEmpty)
                                      _DetailRow(
                                        label: 'Work Arrangement',
                                        value: workMode,
                                      ),

                                    if (priority.isNotEmpty)
                                      _DetailRow(
                                        label: 'Priority',
                                        value: priority,
                                      ),

                                    if (additionalInfo.isNotEmpty)
                                      _DetailRow(
                                        label: 'Additional Instructions',
                                        value: additionalInfo,
                                      ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // ------------------------------------
                            // PROJECT PROGRESS
                            // ------------------------------------
                            _DetailsCard(
                              title: l10n.progress,
                              icon: Icons.timeline_rounded,
                              child: _MilestoneProgressTracker(
                                milestones: data['milestones'],
                                updatedAt: data['updatedAt'],
                              ),
                            ),

                            const SizedBox(height: 24),

                            DeveloperReviewWidget(
                              projectId: projectId,
                              projectTitle:
                                  data['title']?.toString() ?? 'Project',
                              developerId:
                                  (data['developerId'] ??
                                          data['assignedDeveloperId'] ??
                                          '')
                                      .toString(),
                              projectStatus: data['status']?.toString() ?? '',
                              progress: calculatedProgress,
                            ),

                            // ------------------------------------
                            // FINAL ACCEPTED PLAN
                            // ------------------------------------
                            if (acceptedCost ||
                                acceptedTimeline ||
                                acceptedTerms ||
                                plan.isNotEmpty ||
                                estimate.isNotEmpty ||
                                acceptedScope.isNotEmpty) ...[
                              const SizedBox(height: 14),

                              _DetailsCard(
                                title: 'Final Accepted Plan & Estimate',
                                icon: Icons.task_alt_rounded,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((plan['projectSummary']?.toString() ??
                                            '')
                                        .isNotEmpty) ...[
                                      const Text(
                                        'Project Summary',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(plan['projectSummary'].toString()),
                                      const SizedBox(height: 14),
                                    ],

                                    if (acceptedScope.isNotEmpty) ...[
                                      const Text(
                                        'Accepted Scope',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      for (final item in acceptedScope)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 6,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons.check_circle_outline,
                                                size: 18,
                                                color: Color(0xFF16A34A),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(child: Text(item)),
                                            ],
                                          ),
                                        ),

                                      const SizedBox(height: 14),
                                    ],

                                    if (estimate.isNotEmpty) ...[
                                      const Text(
                                        'Estimate Details',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      for (final entry in estimate.entries)
                                        if (entry.value != null &&
                                            entry.value is! Map &&
                                            entry.value is! List)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  flex: 2,
                                                  child: Text(
                                                    _formatPlanLabel(entry.key),
                                                    style: const TextStyle(
                                                      color: Color(0xFF667085),
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 3,
                                                  child: Text(
                                                    entry.value.toString(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                    ],

                                    if (plan['deliveryPhases'] is List &&
                                        (plan['deliveryPhases'] as List)
                                            .isNotEmpty) ...[
                                      const SizedBox(height: 14),
                                      const Text(
                                        'Delivery Phases',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      for (final phase
                                          in plan['deliveryPhases'] as List)
                                        if (phase is Map)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Text(
                                              (phase['name'] ??
                                                      phase['title'] ??
                                                      phase.toString())
                                                  .toString(),
                                            ),
                                          )
                                        else
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 6,
                                            ),
                                            child: Text(phase.toString()),
                                          ),
                                    ],

                                    if (acceptedCost ||
                                        acceptedTimeline ||
                                        acceptedTerms) ...[
                                      const SizedBox(height: 12),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Acceptance Status',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      if (acceptedCost)
                                        const _AcceptedBadge(
                                          label: 'Budget Accepted',
                                        ),

                                      if (acceptedTimeline)
                                        const _AcceptedBadge(
                                          label: 'Timeline Accepted',
                                        ),

                                      if (acceptedTerms)
                                        const _AcceptedBadge(
                                          label: 'Terms Accepted',
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

// ============================================================================
// PROJECT HERO
// ============================================================================

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

// ============================================================================
// HERO CHIP
// ============================================================================

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

// ============================================================================
// STATUS CHIP
// ============================================================================

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

// ============================================================================
// ACTION BUTTON
// ============================================================================

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

// ============================================================================
// DETAILS CARD
// ============================================================================

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

// ============================================================================
// BUDGET / TIMELINE INFO CARD
// ============================================================================

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

// ============================================================================
// ADDITIONAL DETAIL ROW
// ============================================================================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

// ============================================================================
// ACCEPTED BADGE
// ============================================================================

class _AcceptedBadge extends StatelessWidget {
  final String label;

  const _AcceptedBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF16A34A),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF166534),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LIVE MILESTONE PROGRESS — CLIENT READ-ONLY VIEW
// ============================================================================

class _MilestoneProgressTracker extends StatelessWidget {
  final dynamic milestones;
  final dynamic updatedAt;

  const _MilestoneProgressTracker({
    required this.milestones,
    required this.updatedAt,
  });

  static const Color _primary = Color(0xFF4F46E5);
  static const Color _green = Color(0xFF059669);
  static const Color _muted = Color(0xFF667085);
  static const Color _border = Color(0xFFE5E7EB);

  static const List<Map<String, String>> _steps = [
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

  @override
  Widget build(BuildContext context) {
    final completed = milestones is Map
        ? Map<String, dynamic>.from(milestones as Map)
        : <String, dynamic>{};
    final completedCount = _steps
        .where((step) => completed[step['key']] == true)
        .length;
    final total = _steps.length;
    final progress = completedCount / total;
    final currentIndex = _steps.indexWhere(
      (step) => completed[step['key']] != true,
    );
    final allCompleted = currentIndex == -1;

    DateTime? lastUpdated;
    if (updatedAt is Timestamp) {
      lastUpdated = updatedAt.toDate();
    } else if (updatedAt is DateTime) {
      lastUpdated = updatedAt;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Text(
                'Overall Completion',
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                color: _primary,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 10,
            backgroundColor: const Color(0xFFE5E7EB),
            color: allCompleted ? _green : _primary,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 15, color: _muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$completedCount of $total milestones completed',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
            if (lastUpdated != null)
              Text(
                'Updated '
                '${lastUpdated.day.toString().padLeft(2, '0')}/'
                '${lastUpdated.month.toString().padLeft(2, '0')}/'
                '${lastUpdated.year}',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
          ],
        ),
        const SizedBox(height: 24),
        for (int i = 0; i < _steps.length; i++)
          _buildStep(_steps[i], i, completed, currentIndex),
        if (allCompleted)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_rounded, color: _green, size: 25),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All milestones completed! '
                    'The project has reached 100% progress.',
                    style: TextStyle(
                      color: Color(0xFF065F46),
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: _muted, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Progress updates automatically when the '
                    'developer completes a milestone.',
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStep(
    Map<String, String> step,
    int index,
    Map<String, dynamic> completed,
    int currentIndex,
  ) {
    final key = step['key']!;
    final isCompleted = completed[key] == true;
    final isCurrent = index == currentIndex;
    final isUpcoming = !isCompleted && !isCurrent;
    final color = isCompleted
        ? _green
        : isCurrent
        ? _primary
        : const Color(0xFF98A2B3);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFFD1FAE5)
                        : isCurrent
                        ? const Color(0xFFEEF2FF)
                        : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.4),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_rounded
                        : isCurrent
                        ? Icons.play_arrow_rounded
                        : Icons.lock_outline_rounded,
                    color: color,
                    size: 18,
                  ),
                ),
                if (index != _steps.length - 1)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: isCompleted ? _green : const Color(0xFFE5E7EB),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 15),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFFF5F3FF) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent ? const Color(0xFFC7D2FE) : _border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          step['title']!,
                          style: TextStyle(
                            color: isUpcoming
                                ? _muted
                                : const Color(0xFF111827),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      _statusPill(
                        isCompleted
                            ? 'COMPLETED'
                            : isCurrent
                            ? 'CURRENT'
                            : 'UPCOMING',
                        color,
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    step['description']!,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  if (isCompleted) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.verified_rounded, color: _green, size: 15),
                        SizedBox(width: 5),
                        Text(
                          'Completed successfully',
                          style: TextStyle(
                            color: _green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  Widget _statusPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

// ============================================================================
// LOADING INDICATOR
// ============================================================================

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

// ============================================================================
// ERROR CARD
// ============================================================================

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

// ============================================================================
// BACKGROUND AMBIENT PAINTER
// ============================================================================

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
