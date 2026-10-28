import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../services/payment_checkout.dart';

class ProjectPaymentCard extends StatefulWidget {
  final String projectId;
  final double projectTotal;
  final String currency;

  const ProjectPaymentCard({
    super.key,
    required this.projectId,
    required this.projectTotal,
    this.currency = 'INR',
  });

  @override
  State<ProjectPaymentCard> createState() => _ProjectPaymentCardState();
}

class _ProjectPaymentCardState extends State<ProjectPaymentCard> {
  late final PaymentCheckout _checkout;
  final TextEditingController _amountController = TextEditingController();

  bool _isProcessing = false;

  static const int maxPayments = 3;

  FirebaseFunctions get _functions =>
      FirebaseFunctions.instanceFor(region: 'us-central1');

  Query<Map<String, dynamic>> get _paymentsQuery => FirebaseFirestore.instance
      .collection('payments')
      .where('projectId', isEqualTo: widget.projectId)
      .where('status', isEqualTo: 'verified');

  @override
  void initState() {
    super.initState();
    _checkout = createPaymentCheckout(
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentError,
      onDismissed: _handleCheckoutDismissed,
      onExternalWallet: _handleExternalWallet,
    );
  }

  String get _currencySymbol {
    switch (widget.currency.toUpperCase()) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '${widget.currency} ';
    }
  }

  String _money(double amount) {
    return '$_currencySymbol${amount.toStringAsFixed(2)}';
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();

    if (value is String) {
      return double.tryParse(
            value.replaceAll(',', '').replaceAll('₹', '').trim(),
          ) ??
          0.0;
    }

    return 0.0;
  }

  @override
  void dispose() {
    _checkout.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _createPaymentOrder(double amount) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    var checkoutOpened = false;

    try {
      final callable = _functions.httpsCallable('createRazorpayOrder');

      final response = await callable.call({
        'projectId': widget.projectId,
        'amount': amount,
      });

      final data = Map<String, dynamic>.from(response.data as Map);

      if (data['success'] != true ||
          data['orderId'] == null ||
          data['keyId'] == null) {
        throw Exception('Unable to create payment order.');
      }

      if (data['reconcileRequired'] == true) {
        final reconciliation = await _functions
            .httpsCallable('verifyRazorpayPayment')
            .call({'reconcileOrderId': data['orderId']});
        final reconciliationData = Map<String, dynamic>.from(
          reconciliation.data as Map,
        );

        if (reconciliationData['success'] != true ||
            reconciliationData['verified'] != true) {
          throw Exception('The captured payment could not be reconciled.');
        }

        if (mounted) {
          _amountController.clear();
          _showMessage('Payment verified successfully!');
        }
        return;
      }

      final amountInPaise = data['amount'] as int;

      _checkout.open({
        'key': data['keyId'],
        'amount': amountInPaise,
        'currency': data['currency'] ?? 'INR',
        'order_id': data['orderId'],
        'name': 'SkillBridge',
        'description': 'Project payment',
        'prefill': {},
        'notes': {'projectId': widget.projectId},
        'theme': {'color': '#2563EB'},
      });

      checkoutOpened = true;
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        'createRazorpayOrder failed: '
        'code=${error.code}, message=${error.message}, '
        'details=${error.details}',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage(
          'Could not create payment order '
          '(${error.code}): ${error.message ?? 'Check your connection and try again.'}',
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Create payment order error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage('Unable to start payment: $error');
      }
    } finally {
      if (!checkoutOpened && mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handlePaymentSuccess({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      if (orderId.isEmpty || paymentId.isEmpty || signature.isEmpty) {
        throw Exception('Incomplete payment verification details.');
      }

      final callable = _functions.httpsCallable('verifyRazorpayPayment');

      final result = await callable.call({
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      });

      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] != true || data['verified'] != true) {
        throw Exception('Payment verification was unsuccessful.');
      }

      if (!mounted) return;

      _amountController.clear();
      setState(() {
        _isProcessing = false;
      });
      _showMessage('Payment verified successfully!');
    } on FirebaseFunctionsException catch (error, stackTrace) {
      debugPrint(
        'verifyRazorpayPayment failed: '
        'code=${error.code}, message=${error.message}, '
        'details=${error.details}',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });
      _showMessage(
        'Payment verification is pending '
        '(${error.code}). Check payment status before retrying.',
      );
    } catch (error, stackTrace) {
      debugPrint('Payment verification error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });
      _showMessage(
        'Payment verification could not be completed. '
        'Check your payment status before trying again.',
      );
    }
  }

  void _handlePaymentError(String message) {
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });
    _showMessage('Payment failed: $message');
  }

  void _handleCheckoutDismissed() {
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });
    _showMessage(
      'Checkout was closed. Your order is retained safely; you can retry.',
    );
  }

  void _handleExternalWallet(String walletName) {
    if (!mounted) return;

    _showMessage('External wallet selected: $walletName');
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _paymentsQuery.snapshots(),
      builder: (context, snapshot) {
        final documents = snapshot.data?.docs ?? [];

        final successfulDocs = documents.where((doc) {
          final payment = doc.data();
          return (payment['status'] ?? '').toString().toLowerCase() ==
              'verified';
        }).toList();

        double totalPaid = 0;

        for (final doc in successfulDocs) {
          totalPaid += _toDouble(doc.data()['amount']);
        }

        final remaining = (widget.projectTotal - totalPaid).clamp(
          0.0,
          double.infinity,
        );

        final successfulPayments = successfulDocs.length;
        final isFullyPaid = remaining <= 0.009;
        final isLimitReached = successfulPayments >= maxPayments;
        final canPay = !isFullyPaid && !isLimitReached && !snapshot.hasError;

        final progress = widget.projectTotal > 0
            ? (totalPaid / widget.projectTotal).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Color(0xFF2563EB),
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Project Payments',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Track your project payment progress',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    label: isFullyPaid ? 'Paid' : 'In Progress',
                    color: isFullyPaid
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF2563EB),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (snapshot.hasError)
                const _InfoMessage(
                  icon: Icons.error_outline,
                  message:
                      'Unable to load payment details. Please try again later.',
                  color: Colors.red,
                )
              else if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL PROJECT AMOUNT',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _money(widget.projectTotal),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}% paid',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _AmountTile(
                        label: 'Total Paid',
                        amount: _money(totalPaid),
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFF16A34A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _AmountTile(
                        label: 'Remaining',
                        amount: _money(remaining),
                        icon: Icons.hourglass_bottom,
                        color: const Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Payment installments',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$successfulPayments / $maxPayments completed',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(maxPayments, (index) {
                    final completed = index < successfulPayments;

                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(
                          right: index == maxPayments - 1 ? 0 : 8,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: completed
                              ? const Color(0xFFDCFCE7)
                              : theme.dividerColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: completed
                                ? const Color(0xFF16A34A)
                                : theme.dividerColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              completed
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 20,
                              color: completed
                                  ? const Color(0xFF16A34A)
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Payment ${index + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: completed
                                    ? const Color(0xFF15803D)
                                    : theme.textTheme.bodyMedium?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Make a Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  isFullyPaid
                      ? 'This project is fully paid.'
                      : isLimitReached
                      ? 'You have completed all 3 payments.'
                      : successfulPayments == maxPayments - 1
                      ? 'Your final payment must cover the entire remaining balance.'
                      : 'Enter any amount up to ${_money(remaining)}.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _amountController,
                  enabled: canPay && !_isProcessing,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Payment amount',
                    hintText: 'Enter amount',
                    prefixText: '$_currencySymbol ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Pay remaining balance',
                      onPressed: canPay && !_isProcessing
                          ? () {
                              _amountController.text = remaining
                                  .toStringAsFixed(2);
                            }
                          : null,
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: canPay && !_isProcessing
                        ? () async {
                            if (_isProcessing) return;

                            final amount =
                                double.tryParse(
                                  _amountController.text.trim(),
                                ) ??
                                0.0;

                            if (amount <= 0 || amount > remaining) {
                              _showMessage('Enter a valid payment amount.');
                              return;
                            }

                            if (successfulPayments == 2 &&
                                (remaining - amount).abs() > 0.009) {
                              _showMessage(
                                'Your final payment must cover the full remaining balance.',
                              );
                              return;
                            }

                            await _createPaymentOrder(amount);
                          }
                        : null,
                    icon: _isProcessing
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isFullyPaid
                                ? Icons.check_circle
                                : Icons.lock_outline,
                          ),
                    label: Text(
                      isFullyPaid
                          ? 'Project Fully Paid'
                          : isLimitReached
                          ? 'Payment Limit Reached'
                          : 'Pay Now',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: theme.disabledColor.withValues(
                        alpha: 0.15,
                      ),
                      disabledForegroundColor: Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: Colors.grey),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Only verified successful payments count toward '
                        'your 3-payment limit. Failed payments do not count.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 21),
                    const SizedBox(width: 9),
                    const Expanded(
                      child: Text(
                        'Payment History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${successfulDocs.length} records',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (successfulDocs.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.dividerColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 30,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No successful payments yet',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your payment history will appear here.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...successfulDocs.map((doc) {
                    final payment = doc.data();
                    final amount = _toDouble(payment['amount']);
                    final paymentDate = payment['createdAt'];

                    String dateText = 'Date unavailable';

                    if (paymentDate is Timestamp) {
                      final date = paymentDate.toDate();
                      dateText =
                          '${date.day.toString().padLeft(2, '0')}/'
                          '${date.month.toString().padLeft(2, '0')}/'
                          '${date.year}';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment ${successfulDocs.indexOf(doc) + 1}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  dateText,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+${_money(amount)}',
                            style: const TextStyle(
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final String amount;
  final IconData icon;
  final Color color;

  const _AmountTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _InfoMessage({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
