import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClientPaymentsScreen extends StatelessWidget {
  const ClientPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Please login again.'));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Payments',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collectionGroup('payments')
            .where('clientId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load payments.\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final payments = snapshot.data?.docs ?? [];

          if (payments.isEmpty) {
            return const _EmptyPayments();
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: payments.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final payment = payments[index].data();

              return _PaymentCard(payment: payment);
            },
          );
        },
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;

  const _PaymentCard({required this.payment});

  String _formatStatus(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';

      case 'paid':
        return 'Paid';

      case 'failed':
        return 'Failed';

      case 'refunded':
        return 'Refunded';

      case 'cancelled':
        return 'Cancelled';

      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFD97706);

      case 'paid':
        return const Color(0xFF16A34A);

      case 'failed':
        return const Color(0xFFDC2626);

      case 'refunded':
        return const Color(0xFF7C3AED);

      case 'cancelled':
        return const Color(0xFF64748B);

      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatPaymentType(String type) {
    switch (type) {
      case 'advance':
        return 'Advance Payment';

      case 'final':
        return 'Final Payment';

      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = payment['projectTitle']?.toString() ?? 'Project Payment';

    final projectId = payment['projectId']?.toString() ?? '';

    final paymentType = payment['paymentType']?.toString() ?? '';

    final amount = payment['amount']?.toString() ?? '';

    final status = payment['status']?.toString() ?? 'pending';

    final statusColor = _statusColor(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.currency_rupee_rounded,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (paymentType.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        _formatPaymentType(paymentType),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatStatus(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              const Text(
                'Amount',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const Spacer(),
              Text(
                amount.isEmpty ? 'Not specified' : '₹$amount',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),

          if (projectId.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Project ID: $projectId',
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyPayments extends StatelessWidget {
  const _EmptyPayments();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 18),
            Text(
              'No payments yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your project payment records will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}
