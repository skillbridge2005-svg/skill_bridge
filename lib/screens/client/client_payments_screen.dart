import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart' as pw;
import 'package:pdf/widgets.dart' as pdfw;
import 'package:printing/printing.dart';

import '../../localization/app_localizations.dart';

// ---------------------------------------------------------------- THEME
const Color _green = Color(0xFF249B50);
const Color _greenDark = Color(0xFF173B2B);
const Color _greenLight = Color(0xFFDCFCE7);
const Color _greenPale = Color(0xFFF0FDF4);
const Color _greenSoft = Color(0xFFE8F7ED);
const Color _mint = Color(0xFFF6FCF7);
const Color _indigo = Color(0xFF4F46E5);
const Color _amber = Color(0xFFD97706);
const Color _ink = Color(0xFF111827);
const Color _muted = Color(0xFF64748B);
const Color _border = Color(0xFFDDECE1);
const Color _bg = Color(0xFFF7FBF8);
const List<String> _monthNames = [
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
// ---------------------------------------------------------------- HELPERS
String _normalized(dynamic value) =>
    (value?.toString() ?? '').toLowerCase().trim();
double _amountOf(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

/// Formats with Indian digit grouping, e.g. 1234567 -> 12,34,567.
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

DateTime? _paymentDate(Map<String, dynamic> payment) {
  for (final key in ['paidAt', 'createdAt', 'updatedAt']) {
    final value = payment[key];
    if (value is Timestamp) {
      return value.toDate();
    }
  }
  return null;
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')} '
    '${_monthNames[date.month - 1]} ${date.year}';
Color _statusColor(String status) {
  switch (_normalized(status)) {
    case 'pending':
      return const Color(0xFFB7791F);
    case 'paid':
      return _green;
    case 'failed':
      return const Color(0xFFD64545);
    case 'refunded':
      return const Color(0xFF6B46C1);
    case 'cancelled':
      return const Color(0xFF64748B);
    default:
      return const Color(0xFF718096);
  }
}

Color _statusBackground(String status) {
  switch (_normalized(status)) {
    case 'pending':
      return const Color(0xFFFFF5D6);
    case 'paid':
      return const Color(0xFFE7F7ED);
    case 'failed':
      return const Color(0xFFFFE8E8);
    case 'refunded':
      return const Color(0xFFF0E9FF);
    case 'cancelled':
      return const Color(0xFFEDF0F3);
    default:
      return const Color(0xFFEDF0F3);
  }
}

IconData _statusIcon(String status) {
  switch (_normalized(status)) {
    case 'pending':
      return Icons.hourglass_top_rounded;
    case 'paid':
      return Icons.check_circle_rounded;
    case 'failed':
      return Icons.error_rounded;
    case 'refunded':
      return Icons.replay_circle_filled_rounded;
    case 'cancelled':
      return Icons.cancel_rounded;
    default:
      return Icons.receipt_long_rounded;
  }
}

// =====================================================================
//                              SCREEN
// =====================================================================
class ClientPaymentsScreen extends StatelessWidget {
  const ClientPaymentsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text(
            l10n.loginAgain,
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _greenDark,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Payments',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 21,
            letterSpacing: -0.4,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF173B2B), Color(0xFF205C3A), Color(0xFF249B50)],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _PaymentsAmbientPainter()),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .where('clientId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: _PaymentsLoader());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _PaymentsErrorCard(
                      message: '${l10n.somethingWentWrong}\n${snapshot.error}',
                    ),
                  ),
                );
              }
              final payments = snapshot.data?.docs ?? [];
              if (payments.isEmpty) {
                return const _EmptyPayments();
              }
              return _FilteredPaymentsList(payments: payments);
            },
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//                       PROJECT TITLE LOOKUP
// =====================================================================
class _ProjectTitle extends StatelessWidget {
  final String projectId;
  final String paymentTitle;
  const _ProjectTitle({required this.projectId, required this.paymentTitle});
  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 15.5,
      fontWeight: FontWeight.w800,
      color: _greenDark,
    );
    if (paymentTitle.trim().isNotEmpty) {
      return Text(
        paymentTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: titleStyle,
      );
    }
    if (projectId.trim().isEmpty) {
      return const Text(
        'Project name unavailable',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _muted,
        ),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(projectId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text(
            'Unable to load project name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _muted,
            ),
          );
        }
        final data = snapshot.data?.data();
        final title =
            data?['title'] ??
            data?['projectTitle'] ??
            data?['projectName'] ??
            data?['name'];
        final displayTitle = title?.toString().trim();
        return Text(
          displayTitle != null && displayTitle.isNotEmpty
              ? displayTitle
              : 'Project name unavailable',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        );
      },
    );
  }
}

// =====================================================================
//                      FILTERED PAYMENT LIST
// =====================================================================
class _FilteredPaymentsList extends StatefulWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> payments;
  const _FilteredPaymentsList({required this.payments});
  @override
  State<_FilteredPaymentsList> createState() => _FilteredPaymentsListState();
}

class _FilteredPaymentsListState extends State<_FilteredPaymentsList> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';
  String _status = 'all';
  String _type = 'all';
  late Future<Map<String, String>> _projectTitlesFuture;
  @override
  void initState() {
    super.initState();
    _projectTitlesFuture = _loadProjectTitles(widget.payments);
  }

  @override
  void didUpdateWidget(covariant _FilteredPaymentsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameProjectIds(oldWidget.payments, widget.payments)) {
      _projectTitlesFuture = _loadProjectTitles(widget.payments);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _projectIds(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> payments,
  ) {
    return payments
        .where((document) => _paymentTitle(document.data()).isEmpty)
        .map(
          (document) => document.data()['projectId']?.toString().trim() ?? '',
        )
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  bool _sameProjectIds(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> first,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> second,
  ) {
    final firstIds = _projectIds(first);
    final secondIds = _projectIds(second);
    if (firstIds.length != secondIds.length) return false;
    for (var index = 0; index < firstIds.length; index++) {
      if (firstIds[index] != secondIds[index]) return false;
    }
    return true;
  }

  String _paymentTitle(Map<String, dynamic> payment) {
    for (final key in ['projectTitle', 'projectName', 'title']) {
      final title = payment[key]?.toString().trim() ?? '';
      if (title.isNotEmpty) return title;
    }
    return '';
  }

  Future<Map<String, String>> _loadProjectTitles(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> payments,
  ) async {
    final ids = _projectIds(payments);
    final projectDocuments = await Future.wait(
      ids.map(
        (id) => FirebaseFirestore.instance.collection('projects').doc(id).get(),
      ),
    );
    final projectTitles = <String, String>{};
    for (final document in projectDocuments) {
      final data = document.data();
      for (final field in ['title', 'projectTitle', 'projectName', 'name']) {
        final title = data?[field]?.toString().trim() ?? '';
        if (title.isNotEmpty) {
          projectTitles[document.id] = title;
          break;
        }
      }
    }
    return projectTitles;
  }

  int _countStatus(String status) {
    if (status == 'all') return widget.payments.length;
    return widget.payments
        .where((document) => _normalized(document.data()['status']) == status)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<Map<String, String>>(
      future: _projectTitlesFuture,
      builder: (context, projectTitlesSnapshot) {
        final projectTitles = projectTitlesSnapshot.data ?? const {};
        final searchTerm = _search.toLowerCase();
        final filteredPayments = widget.payments.where((document) {
          final payment = document.data();
          final status = _normalized(payment['status']);
          final type = _normalized(payment['paymentType']);
          final title =
              '${_paymentTitle(payment)} '
                      '${projectTitles[payment['projectId']?.toString()] ?? ''}'
                  .toLowerCase();
          final projectId = _normalized(payment['projectId']);
          final matchesSearch =
              searchTerm.isEmpty ||
              title.contains(searchTerm) ||
              projectId.contains(searchTerm);
          final matchesStatus = _status == 'all' || status == _status;
          final matchesType =
              _type == 'all' ||
              (_type == 'other'
                  ? type != 'advance' && type != 'final'
                  : type == _type);
          return matchesSearch && matchesStatus && matchesType;
        }).toList();
        final pendingPayments = filteredPayments
            .where(
              (document) => _normalized(document.data()['status']) == 'pending',
            )
            .toList();
        final paymentHistory = filteredPayments
            .where(
              (document) => _normalized(document.data()['status']) != 'pending',
            )
            .toList();
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The Payment Overview card has been removed.
                  _buildFilters(),
                  if (projectTitlesSnapshot.connectionState ==
                      ConnectionState.waiting) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Loading project names...',
                      style: TextStyle(fontSize: 12, color: _muted),
                    ),
                  ],
                  if (projectTitlesSnapshot.hasError) ...[
                    const SizedBox(height: 16),
                    _PaymentsErrorCard(
                      message:
                          'Unable to search by project name. '
                          '${projectTitlesSnapshot.error}',
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: _greenPale,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDDECE1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.receipt_long_rounded,
                          color: _green,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${filteredPayments.length} payment(s) found',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _greenDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (filteredPayments.isEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A249B50),
                            blurRadius: 20,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            height: 70,
                            width: 70,
                            decoration: BoxDecoration(
                              color: _greenPale,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(
                              Icons.search_off_rounded,
                              size: 35,
                              color: _green,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.noPayments,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: _greenDark,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Try changing your search or filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (pendingPayments.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    _PaymentSectionTitle(
                      icon: Icons.hourglass_top_rounded,
                      title: l10n.pending,
                      subtitle: l10n.advancePayment,
                      color: _amber,
                      count: pendingPayments.length,
                    ),
                    const SizedBox(height: 15),
                    ...pendingPayments.map(
                      (document) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _PaymentCard(
                          payment: document.data(),
                          paymentDocumentId: document.id,
                          isPending: true,
                        ),
                      ),
                    ),
                  ],
                  if (paymentHistory.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    _PaymentSectionTitle(
                      icon: Icons.history_rounded,
                      title: l10n.paymentHistory,
                      subtitle: l10n.paymentDetails,
                      color: _green,
                      count: paymentHistory.length,
                    ),
                    const SizedBox(height: 15),
                    ...paymentHistory.map(
                      (document) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _PaymentCard(
                          payment: document.data(),
                          paymentDocumentId: document.id,
                          isPending: false,
                        ),
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
  }

  // ------------------------------------------------------------- FILTERS
  Widget _buildFilters() {
    const statuses = [
      ('all', 'All', Icons.apps_rounded),
      ('pending', 'Pending', Icons.hourglass_top_rounded),
      ('paid', 'Paid', Icons.check_circle_rounded),
      ('failed', 'Failed', Icons.error_rounded),
      ('refunded', 'Refunded', Icons.replay_circle_filled_rounded),
      ('cancelled', 'Cancelled', Icons.cancel_rounded),
    ];
    const types = [
      ('all', 'All Types'),
      ('advance', 'Advance'),
      ('final', 'Final'),
      ('other', 'Other'),
    ];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFDDECE1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A249B50),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: _greenPale,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.tune_rounded, color: _green, size: 21),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filter Payments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _greenDark,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Find a payment quickly',
                      style: TextStyle(fontSize: 11.5, color: _muted),
                    ),
                  ],
                ),
              ),
              if (_search.isNotEmpty || _status != 'all' || _type != 'all')
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _search = '';
                      _status = 'all';
                      _type = 'all';
                    });
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() => _search = value.trim());
            },
            decoration: InputDecoration(
              hintText: 'Search project name or ID...',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
              prefixIcon: const Icon(Icons.search_rounded, color: _green),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              filled: true,
              fillColor: const Color(0xFFF5FBF6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _green, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'PAYMENT STATUS',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w900,
              color: _muted,
            ),
          ),
          const SizedBox(height: 11),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: statuses.map((s) {
                final selected = _status == s.$1;
                final color = s.$1 == 'all' ? _greenDark : _statusColor(s.$1);
                final count = _countStatus(s.$1);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _status = s.$1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? color : const Color(0xFFF5F9F6),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: selected ? color : const Color(0xFFE4ECE6),
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.18),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            s.$3,
                            size: 15,
                            color: selected ? Colors.white : color,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s.$2,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : _ink,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: 0.22)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: selected ? Colors.white : _muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 19),
          const Text(
            'PAYMENT TYPE',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w900,
              color: _muted,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8F3),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE2EEE5)),
            ),
            child: Row(
              children: types.map((t) {
                final selected = _type == t.$1;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _type = t.$1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        vertical: 11,
                        horizontal: 3,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(11),
                        border: selected
                            ? Border.all(color: const Color(0xFFDCEDE0))
                            : null,
                        boxShadow: selected
                            ? const [
                                BoxShadow(
                                  color: Color(0x0A173B2B),
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        t.$2,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: selected ? _green : _muted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//                    SECTION TITLE AND PAYMENT CARD
// =====================================================================
class _PaymentSectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final int count;
  const _PaymentSectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.count,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.15),
                color.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11.5, color: _muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final String paymentDocumentId;
  final bool isPending;

  const _PaymentCard({
    required this.payment,
    required this.paymentDocumentId,
    required this.isPending,
  });
  String _formatStatus(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context);
    switch (_normalized(status)) {
      case 'pending':
        return l10n.pending;
      case 'paid':
        return l10n.paid;
      case 'failed':
        return l10n.failed;
      case 'refunded':
        return l10n.refunded;
      case 'cancelled':
        return l10n.paymentCancelled;
      default:
        if (status.isEmpty) return 'Unknown';
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  String _formatPaymentType(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context);
    switch (_normalized(type)) {
      case 'advance':
        return l10n.advancePayment;
      case 'final':
        return l10n.finalPayment;
      default:
        if (type.isEmpty) return 'Project Payment';
        return type;
    }
  }

  String _firstNonEmpty(
    Iterable<dynamic> values, {
    String fallback = 'Not provided',
  }) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
    }
    return fallback;
  }

  Future<Map<String, dynamic>?> _readUser(String? uid) async {
    if (uid == null || uid.trim().isEmpty) return null;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return snapshot.data();
    } catch (_) {
      return null;
    }
  }

  Future<void> _printReceipt(BuildContext context) async {
    if (_normalized(payment['status']) != 'paid') return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final projectId = payment['projectId']?.toString() ?? '';
      Map<String, dynamic>? projectData;
      if (projectId.trim().isNotEmpty) {
        final projectSnapshot = await FirebaseFirestore.instance
            .collection('projects')
            .doc(projectId)
            .get();
        projectData = projectSnapshot.data();
      }

      final clientId = _firstNonEmpty([
        payment['clientId'],
        projectData?['clientId'],
      ], fallback: '');
      final developerId = _firstNonEmpty([
        payment['developerId'],
        payment['developerUid'],
        payment['freelancerId'],
        projectData?['developerId'],
        projectData?['developerUid'],
        projectData?['freelancerId'],
        projectData?['assignedDeveloperId'],
      ], fallback: '');

      final userSnapshots = await Future.wait([
        _readUser(clientId),
        _readUser(developerId),
      ]);
      final clientData = userSnapshots[0];
      final developerData = userSnapshots[1];

      final projectName = _firstNonEmpty([
        payment['projectTitle'],
        payment['projectName'],
        payment['title'],
        projectData?['title'],
        projectData?['projectTitle'],
        projectData?['projectName'],
        projectData?['name'],
      ], fallback: 'Project');
      final clientName = _firstNonEmpty([
        payment['clientName'],
        projectData?['clientName'],
        clientData?['displayName'],
        clientData?['fullName'],
        clientData?['name'],
        clientData?['username'],
        clientData?['email'],
      ]);
      final developerName = _firstNonEmpty([
        payment['developerName'],
        payment['freelancerName'],
        projectData?['developerName'],
        projectData?['freelancerName'],
        developerData?['displayName'],
        developerData?['fullName'],
        developerData?['name'],
        developerData?['username'],
        developerData?['email'],
      ]);
      final paymentId = _firstNonEmpty([
        payment['razorpayPaymentId'],
        payment['paymentId'],
        payment['transactionId'],
        payment['providerPaymentId'],
      ], fallback: paymentDocumentId);
      final receiptNumber = _firstNonEmpty(
        [payment['receiptNumber']],
        fallback:
            'SB-${paymentDocumentId.isEmpty ? paymentId : paymentDocumentId}',
      );
      final paymentMethod = _firstNonEmpty([
        payment['paymentMethod'],
        payment['method'],
        payment['methodType'],
      ]);
      final amount = _amountOf(payment['amount']);
      final date = _paymentDate(payment);
      final dateText = date == null ? 'Not available' : _formatDate(date);

      final pdf = pdfw.Document();
      pdf.addPage(
        pdfw.Page(
          pageFormat: pw.PdfPageFormat.a4,
          margin: const pdfw.EdgeInsets.all(36),
          build: (pageContext) => pdfw.Container(
            decoration: pdfw.BoxDecoration(
              border: pdfw.Border.all(color: pw.PdfColor.fromInt(0xFFDDECE1)),
              borderRadius: pdfw.BorderRadius.circular(16),
            ),
            padding: const pdfw.EdgeInsets.all(28),
            child: pdfw.Column(
              crossAxisAlignment: pdfw.CrossAxisAlignment.stretch,
              children: [
                pdfw.Container(
                  padding: const pdfw.EdgeInsets.all(20),
                  decoration: pdfw.BoxDecoration(
                    color: pw.PdfColor.fromInt(0xFF173B2B),
                    borderRadius: pdfw.BorderRadius.circular(12),
                  ),
                  child: pdfw.Column(
                    crossAxisAlignment: pdfw.CrossAxisAlignment.start,
                    children: [
                      pdfw.Text(
                        'SkillBridge',
                        style: pdfw.TextStyle(
                          color: pw.PdfColor.fromInt(0xFFFFFFFF),
                          fontSize: 25,
                          fontWeight: pdfw.FontWeight.bold,
                        ),
                      ),
                      pdfw.SizedBox(height: 5),
                      pdfw.Text(
                        'PAYMENT RECEIPT',
                        style: pdfw.TextStyle(
                          color: pw.PdfColor.fromInt(0xFFD1FAE5),
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                pdfw.SizedBox(height: 24),
                pdfw.Container(
                  padding: const pdfw.EdgeInsets.all(18),
                  decoration: pdfw.BoxDecoration(
                    color: pw.PdfColor.fromInt(0xFFF0FDF4),
                    borderRadius: pdfw.BorderRadius.circular(12),
                    border: pdfw.Border.all(
                      color: pw.PdfColor.fromInt(0xFFDDECE1),
                    ),
                  ),
                  child: pdfw.Column(
                    crossAxisAlignment: pdfw.CrossAxisAlignment.start,
                    children: [
                      pdfw.Text(
                        'AMOUNT PAID',
                        style: pdfw.TextStyle(
                          color: pw.PdfColor.fromInt(0xFF64748B),
                          fontSize: 10,
                          fontWeight: pdfw.FontWeight.bold,
                        ),
                      ),
                      pdfw.SizedBox(height: 7),
                      pdfw.Text(
                        'INR ${_formatInr(amount)}',
                        style: pdfw.TextStyle(
                          color: pw.PdfColor.fromInt(0xFF173B2B),
                          fontSize: 27,
                          fontWeight: pdfw.FontWeight.bold,
                        ),
                      ),
                      pdfw.SizedBox(height: 8),
                      pdfw.Text(
                        'Payment status: PAID',
                        style: pdfw.TextStyle(
                          color: pw.PdfColor.fromInt(0xFF249B50),
                          fontSize: 11,
                          fontWeight: pdfw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                pdfw.SizedBox(height: 24),
                pdfw.Text(
                  'PAYMENT DETAILS',
                  style: pdfw.TextStyle(
                    color: pw.PdfColor.fromInt(0xFF173B2B),
                    fontSize: 12,
                    fontWeight: pdfw.FontWeight.bold,
                  ),
                ),
                pdfw.SizedBox(height: 10),
                _receiptRow('Receipt number', receiptNumber),
                _receiptRow('Project', projectName),
                _receiptRow(
                  'Project ID',
                  projectId.isEmpty ? 'Not provided' : projectId,
                ),
                _receiptRow('Payment ID', paymentId),
                _receiptRow(
                  'Payment type',
                  _firstNonEmpty([
                    payment['paymentType'],
                  ], fallback: 'Project Payment'),
                ),
                _receiptRow('Payment date', dateText),
                _receiptRow('Payment method', paymentMethod),
                pdfw.SizedBox(height: 20),
                pdfw.Text(
                  'PARTIES',
                  style: pdfw.TextStyle(
                    color: pw.PdfColor.fromInt(0xFF173B2B),
                    fontSize: 12,
                    fontWeight: pdfw.FontWeight.bold,
                  ),
                ),
                pdfw.SizedBox(height: 10),
                _receiptRow('Client', clientName),
                _receiptRow('Developer', developerName),
                pdfw.Spacer(),
                pdfw.Divider(color: pw.PdfColor.fromInt(0xFFDDECE1)),
                pdfw.SizedBox(height: 8),
                pdfw.Text(
                  'This receipt acknowledges a payment recorded as successful in SkillBridge. '
                  'Please retain it for your records.',
                  style: pdfw.TextStyle(
                    color: pw.PdfColor.fromInt(0xFF64748B),
                    fontSize: 9,
                  ),
                ),
                pdfw.SizedBox(height: 6),
                pdfw.Text(
                  'Generated by SkillBridge • ${DateTime.now().toLocal().toString().split('.').first}',
                  style: pdfw.TextStyle(
                    color: pw.PdfColor.fromInt(0xFF94A3B8),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await Printing.layoutPdf(
        name: 'SkillBridge_Receipt_$receiptNumber.pdf',
        onLayout: (format) async => pdf.save(),
      );
    } catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not generate receipt: $error'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  pdfw.Widget _receiptRow(String label, String value) {
    return pdfw.Padding(
      padding: const pdfw.EdgeInsets.symmetric(vertical: 7),
      child: pdfw.Row(
        crossAxisAlignment: pdfw.CrossAxisAlignment.start,
        children: [
          pdfw.SizedBox(
            width: 125,
            child: pdfw.Text(
              label,
              style: pdfw.TextStyle(
                color: pw.PdfColor.fromInt(0xFF64748B),
                fontSize: 10,
              ),
            ),
          ),
          pdfw.Expanded(
            child: pdfw.Text(
              value,
              style: pdfw.TextStyle(
                color: pw.PdfColor.fromInt(0xFF111827),
                fontSize: 10,
                fontWeight: pdfw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final projectTitle = payment['projectTitle']?.toString() ?? '';
    final paymentType = payment['paymentType']?.toString() ?? '';
    final projectId = payment['projectId']?.toString() ?? '';
    final status = payment['status']?.toString() ?? 'unknown';
    final date = _paymentDate(payment);
    final amountValue = payment['amount'];
    final amount = amountValue == null
        ? l10n.noData
        : '₹${_formatInr(_amountOf(amountValue))}';
    final statusColor = _statusColor(status);
    final statusBackground = _statusBackground(status);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isPending ? const Color(0xFFF5D9A5) : const Color(0xFFDDECE1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPending
                ? const Color(0x12D97706)
                : const Color(0x0A249B50),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Colored status strip.
          Container(
            height: 5,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  statusColor,
                  statusColor.withValues(alpha: 0.55),
                  statusColor.withValues(alpha: 0.15),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 47,
                      width: 47,
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Icon(
                        _statusIcon(status),
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ProjectTitle(
                            projectId: projectId,
                            paymentTitle: projectTitle,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _formatPaymentType(context, paymentType),
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Text(
                        _formatStatus(context, status),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // Amount block.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        statusBackground.withValues(alpha: 0.65),
                        const Color(0xFFF7FCF8),
                        Colors.white,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.amount,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _muted,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Payment amount',
                              style: TextStyle(fontSize: 10.5, color: _muted),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: Text(
                          amount,
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                // Project ID and date.
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: projectId.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: projectId),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Project ID copied.'),
                                    behavior: SnackBarBehavior.floating,
                                    duration: Duration(seconds: 1),
                                  ),
                                );
                              },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.folder_outlined,
                                size: 15,
                                color: _muted,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Project ID: $projectId',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: _muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (projectId.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(
                                    Icons.copy_rounded,
                                    size: 13,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (date != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.event_rounded, size: 14, color: _muted),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(date),
                        style: const TextStyle(
                          fontSize: 11,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (_normalized(status) == 'paid') ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _printReceipt(context),
                      icon: const Icon(Icons.print_rounded, size: 18),
                      label: const Text('Print Payment Receipt'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _greenDark,
                        backgroundColor: _greenPale,
                        side: const BorderSide(color: Color(0xFFB8E2C5)),
                        padding: const EdgeInsets.symmetric(
                          vertical: 13,
                          horizontal: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
                if (isPending) ...[
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF7E8), Color(0xFFFFFBF2)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFF9E5BD)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: _amber,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            l10n.pending,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//                       EMPTY PAYMENTS SCREEN
// =====================================================================
class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments();
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFF8FCF9)],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFDDECE1)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0A249B50),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const _EmptyPaymentIcon(),
                const SizedBox(height: 22),
                Text(
                  l10n.noPayments,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: _greenDark,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  l10n.paymentHistory,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: _muted,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Your project payment history will appear here once you make a payment.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: Color(0xFF849188),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyPaymentIcon extends StatelessWidget {
  const _EmptyPaymentIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      width: 94,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE5F8EA), Color(0xFFF4FCF5)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFD4EEDB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12249B50),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.receipt_long_rounded, size: 43, color: _green),
    );
  }
}

// =====================================================================
//                           LOADING WIDGET
// =====================================================================
class _PaymentsLoader extends StatelessWidget {
  const _PaymentsLoader();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A249B50),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 34,
            width: 34,
            child: CircularProgressIndicator(color: _green, strokeWidth: 3),
          ),
          SizedBox(height: 16),
          Text(
            'Loading payments...',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _greenDark,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//                            ERROR WIDGET
// =====================================================================
class _PaymentsErrorCard extends StatelessWidget {
  final String message;
  const _PaymentsErrorCard({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF2DADA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEEE),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 32,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'Unable to load payments',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _greenDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, height: 1.5, color: _muted),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
//                         AMBIENT BACKGROUND
// =====================================================================
class _PaymentsAmbientPainter extends CustomPainter {
  const _PaymentsAmbientPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    // Soft green glow in the upper-right corner.
    paint.color = const Color(0xFF249B50).withValues(alpha: 0.045);
    canvas.drawCircle(
      Offset(size.width * 0.98, size.height * 0.08),
      size.width * 0.34,
      paint,
    );
    // Faint mint glow in the lower-left corner.
    paint.color = const Color(0xFF86D9A0).withValues(alpha: 0.055);
    canvas.drawCircle(
      Offset(size.width * 0.02, size.height * 0.72),
      size.width * 0.38,
      paint,
    );
    // Subtle green glow near the lower-right corner.
    paint.color = const Color(0xFF249B50).withValues(alpha: 0.025);
    canvas.drawCircle(
      Offset(size.width * 0.95, size.height * 0.94),
      size.width * 0.28,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
