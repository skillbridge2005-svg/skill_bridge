import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';

class ClientPaymentsScreen extends StatelessWidget {
  const ClientPaymentsScreen({super.key});

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
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF173B2B),
        titleSpacing: 20,
        title: const Text(
          'Payments',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: Color(0xFF173B2B),
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(
              painter: _PaymentsAmbientPainter(),
            ),
          ),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('payments')
                .where('clientId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: _PaymentsLoader(),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _PaymentsErrorCard(
                      message:
                          '${l10n.somethingWentWrong}\n${snapshot.error}',
                    ),
                  ),
                );
              }

              final payments = snapshot.data?.docs ?? [];

              final pendingPayments = payments.where((document) {
                final status = document.data()['status']?.toString() ?? '';

                return status.toLowerCase() == 'pending';
              }).toList();

              final paymentHistory = payments.where((document) {
                final status = document.data()['status']?.toString() ?? '';

                return status.toLowerCase() != 'pending';
              }).toList();

              if (payments.isEmpty) {
                return const _EmptyPayments();
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 1180,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _PaymentsSectionHeading(),
                        if (pendingPayments.isNotEmpty) ...[
                          const SizedBox(height: 26),
                          _PaymentSectionTitle(
                            eyebrow: l10n.pending,
                            title: l10n.pending,
                            subtitle: l10n.advancePayment,
                            color: const Color(0xFFD97706),
                          ),
                          const SizedBox(height: 14),
                          Column(
                            children: pendingPayments.map((paymentDocument) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _PaymentCard(
                                  payment: paymentDocument.data(),
                                  isPending: true,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (paymentHistory.isNotEmpty) ...[
                          SizedBox(
                            height: pendingPayments.isNotEmpty ? 18 : 26,
                          ),
                          _PaymentSectionTitle(
                            eyebrow: l10n.paymentHistory,
                            title: l10n.paymentHistory,
                            subtitle: l10n.paymentDetails,
                            color: const Color(0xFF4F46E5),
                          ),
                          const SizedBox(height: 14),
                          Column(
                            children: paymentHistory.map((paymentDocument) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _PaymentCard(
                                  payment: paymentDocument.data(),
                                  isPending: false,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PaymentsSectionHeading extends StatelessWidget {
  const _PaymentsSectionHeading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.payments.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.25,
            color: Color(0xFF4F46E5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.payments,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.paymentHistory,
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _PaymentSectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Color color;

  const _PaymentSectionTitle({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.25,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.5,
            height: 1.4,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;
  final bool isPending;

  const _PaymentCard({
    required this.payment,
    required this.isPending,
  });

  String _normalizedStatus(String status) {
    return status.trim().toLowerCase();
  }

  String _formatStatus(BuildContext context, String status) {
    final l10n = AppLocalizations.of(context);

    switch (_normalizedStatus(status)) {
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
        if (status.isEmpty) {
          return 'Unknown';
        }

        return status[0].toUpperCase() + status.substring(1);
    }
  }

  Color _statusColor(String status) {
    switch (_normalizedStatus(status)) {
      case 'pending':
        return const Color(0xFFB7791F);
      case 'paid':
        return const Color(0xFF249B50);
      case 'failed':
        return const Color(0xFFD64545);
      case 'refunded':
        return const Color(0xFF6B46C1);
      case 'cancelled':
        return const Color(0xFF718096);
      default:
        return const Color(0xFF718096);
    }
  }

  Color _statusBackground(String status) {
    switch (_normalizedStatus(status)) {
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

  String _formatPaymentType(BuildContext context, String type) {
    final l10n = AppLocalizations.of(context);

    switch (_normalizedStatus(type)) {
      case 'advance':
        return l10n.advancePayment;
      case 'final':
        return l10n.finalPayment;
      default:
        if (type.isEmpty) {
          return 'Project Payment';
        }

        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final projectTitle =
        payment['projectTitle']?.toString() ?? l10n.project;

    final paymentType =
        payment['paymentType']?.toString() ?? '';

    final projectId =
        payment['projectId']?.toString() ?? '';

    final status =
        payment['status']?.toString() ?? 'unknown';

    final dynamic amountValue = payment['amount'];

    final String amount;

    if (amountValue is num) {
      amount = '₹${amountValue.toStringAsFixed(2)}';
    } else {
      amount = '₹${amountValue ?? '0'}';
    }

    final statusColor = _statusColor(status);
    final statusBackground = _statusBackground(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPending
              ? const Color(0xFFFDE3B0)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: isPending
                ? const Color(0x0FD97706)
                : const Color(0x060F172A),
            blurRadius: 17,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 46,
                  width: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7EF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isPending
                        ? Icons.pending_actions_rounded
                        : Icons.currency_rupee_rounded,
                    color: const Color(0xFF4F46E5),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        projectTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF173B2B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatPaymentType(
                          context,
                          paymentType,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatStatus(context, status),
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.amount,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  Text(
                    amount.isEmpty ? l10n.noData : amount,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                const Icon(
                  Icons.folder_outlined,
                  size: 15,
                  color: Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Project ID: $projectId',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (isPending) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7E8),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: Color(0xFFD97706),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.pending,
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
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
    );
  }
}

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PaymentsSectionHeading(),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 52,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x070F172A),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const _EmptyPaymentIcon(),
                    const SizedBox(height: 18),
                    Text(
                      l10n.noPayments,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.paymentHistory,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your project payment history will appear here once you make a payment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Colors.grey,
                ),
              ),
            ],
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
      height: 82,
      width: 82,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7EF),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Icon(
        Icons.receipt_long_rounded,
        size: 40,
        color: Color(0xFF249B50),
      ),
    );
  }
}

class _PaymentsLoader extends StatelessWidget {
  const _PaymentsLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: Color(0xFF249B50),
      ),
    );
  }
}

class _PaymentsErrorCard extends StatelessWidget {
  final String message;

  const _PaymentsErrorCard({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE8EDF2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to load payments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF173B2B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentsAmbientPainter extends CustomPainter {
  const _PaymentsAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF249B50).withValues(alpha: 0.025)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * 0.9, 80),
      120,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.05, size.height * 0.75),
      150,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}