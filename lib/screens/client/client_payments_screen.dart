import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ClientPaymentsScreen extends StatelessWidget {
  const ClientPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FC),
        appBar: AppBar(
          title: const Text('Payments'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF173B2B),
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Please login to view your payments.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payments',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173B2B),
              ),
            ),
            SizedBox(height: 2),
            Text(
              'SkillBridge payment history',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _PaymentsAmbientPainter()),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              // IMPORTANT:
              // Payments are stored in:
              // payments/{razorpayPaymentId}
              //
              // Therefore we use collection('payments')
              // instead of collectionGroup('payments').
              stream: FirebaseFirestore.instance
                  .collection('payments')
                  .where('clientId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _PaymentsLoader();
                }

                if (snapshot.hasError) {
                  return const _PaymentsErrorCard();
                }

                final payments = snapshot.data?.docs ?? [];

                if (payments.isEmpty) {
                  return const _EmptyPayments();
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    const _PaymentsSectionHeading(),
                    const SizedBox(height: 16),

                    ...payments.map((paymentDocument) {
                      final payment = paymentDocument.data();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _PaymentCard(payment: payment),
                      );
                    }),
                  ],
                );
              },
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'FINANCE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
            color: Color(0xFF249B50),
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Payment history',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF173B2B),
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Track your project payments and transaction status.',
          style: TextStyle(fontSize: 13, height: 1.4, color: Colors.grey),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final Map<String, dynamic> payment;

  const _PaymentCard({required this.payment});

  String _normalizedStatus(String status) {
    final normalized = status.toLowerCase().trim();

    // Backend stores:
    // status: "verified"
    //
    // UI displays:
    // "Paid"
    if (normalized == 'verified') {
      return 'paid';
    }

    return normalized;
  }

  String _formatStatus(String status) {
    switch (_normalizedStatus(status)) {
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

  String _formatPaymentType(String type) {
    switch (type.toLowerCase()) {
      case 'advance':
        return 'Advance Payment';

      case 'final':
        return 'Final Payment';

      default:
        if (type.isEmpty) {
          return 'Project Payment';
        }

        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String projectTitle =
        payment['projectTitle']?.toString() ?? 'Project Payment';

    final String projectId = payment['projectId']?.toString() ?? 'N/A';

    final String paymentType = payment['paymentType']?.toString() ?? '';

    final String status = payment['status']?.toString() ?? 'unknown';

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
        border: Border.all(color: const Color(0xFFE8EDF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Color(0xFF249B50),
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
                        _formatPaymentType(paymentType),
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
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatStatus(status),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FB),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Amount',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF173B2B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 13),

            Row(
              children: [
                const Icon(Icons.folder_outlined, size: 15, color: Colors.grey),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _EmptyPaymentIcon(),
            const SizedBox(height: 20),
            const Text(
              'No payments yet',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: Color(0xFF173B2B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your project payment history will appear here once you make a payment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.5, color: Colors.grey),
            ),
          ],
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
      child: CircularProgressIndicator(color: Color(0xFF249B50)),
    );
  }
}

class _PaymentsErrorCard extends StatelessWidget {
  const _PaymentsErrorCard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8EDF2)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 42,
                color: Colors.redAccent,
              ),
              SizedBox(height: 12),
              Text(
                'Unable to load payments',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF173B2B),
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Please try again later.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentsAmbientPainter extends CustomPainter {
  const _PaymentsAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF249B50).withOpacity(0.025)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(size.width * 0.9, 80), 120, paint);

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
