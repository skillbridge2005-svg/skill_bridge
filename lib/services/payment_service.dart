import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'razorpay_web_stub.dart'
    if (dart.library.js_interop) 'razorpay_web.dart';

class PaymentService {
  Razorpay? _razorpay;

  PaymentService() {
    if (!kIsWeb) {
      _razorpay = Razorpay();

      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);

      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);

      _razorpay!.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    }
  }

  Future<void> startPayment({
    required double amount,
    required String projectId,
    required String email,
    String? contact,
  }) async {
    try {
      if (kIsWeb) {
        final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

        final callable = functions.httpsCallable('createRazorpayOrder');

        final result = await callable.call({'projectId': projectId});

        final data = Map<String, dynamic>.from(result.data);

        final String orderId = data['orderId'];
        final String keyId = data['keyId'];
        final int amountInPaise = data['amount'];

        final options = {
          'key': keyId,
          'amount': amountInPaise,
          'currency': 'INR',
          'name': 'SkillBridge',
          'description': 'Demo Project Payment',
          'order_id': orderId,
          'prefill': {
            'email': email,
            if (contact != null && contact.isNotEmpty) 'contact': contact,
          },
          'notes': {'projectId': projectId},
          'theme': {'color': '#249B50'},
          'retry': {'enabled': true, 'max_count': 3},
        };

        await openRazorpayWeb(
          options: options,
          onSuccess: _handleWebPaymentSuccess,
        );

        return;
      }

      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

      final callable = functions.httpsCallable('createRazorpayOrder');

      final result = await callable.call({
        'amount': amount,
        'projectId': projectId,
      });

      final data = Map<String, dynamic>.from(result.data);

      final String orderId = data['orderId'];
      final String keyId = data['keyId'];
      final int amountInPaise = data['amount'];

      final options = {
        'key': keyId,
        'amount': amountInPaise,
        'currency': 'INR',
        'name': 'SkillBridge',
        'description': 'Project Payment',
        'order_id': orderId,
        'prefill': {
          'email': email,
          if (contact != null && contact.isNotEmpty) 'contact': contact,
        },
        'notes': {'projectId': projectId},
        'theme': {'color': '#249B50'},
        'retry': {'enabled': true, 'max_count': 3},
      };

      _razorpay!.open(options);
    } catch (e) {
      print('Payment initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _handleWebPaymentSuccess(
    String? paymentId,
    String? orderId,
    String? signature,
  ) async {
    print('========== PAYMENT SUCCESS ==========');
    print('Payment ID: $paymentId');
    print('Order ID: $orderId');
    print('Signature: $signature');
    print('=====================================');

    await _verifyPayment(
      orderId: orderId,
      paymentId: paymentId,
      signature: signature,
    );
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('========== PAYMENT SUCCESS ==========');
    print('Payment ID: ${response.paymentId}');
    print('Order ID: ${response.orderId}');
    print('Signature: ${response.signature}');
    print('=====================================');

    await _verifyPayment(
      orderId: response.orderId,
      paymentId: response.paymentId,
      signature: response.signature,
    );
  }

  Future<void> _verifyPayment({
    required String? orderId,
    required String? paymentId,
    required String? signature,
  }) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

      final callable = functions.httpsCallable('verifyRazorpayPayment');

      final result = await callable.call({
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
      });

      final data = Map<String, dynamic>.from(result.data);

      if (data['verified'] == true) {
        print('====================================');
        print('PAYMENT VERIFIED SUCCESSFULLY');
        print('Payment ID: ${data['paymentId']}');
        print('Order ID: ${data['orderId']}');
        print('Project ID: ${data['projectId']}');
        print('Amount: ${data['amount']} ${data['currency']}');
        print('====================================');
      } else {
        print('Payment verification failed.');
      }
    } catch (e) {
      print('Payment verification error: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print('========== PAYMENT FAILED ==========');
    print('Code: ${response.code}');
    print('Message: ${response.message}');
    print('====================================');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print('========== EXTERNAL WALLET ==========');
    print('Wallet: ${response.walletName}');
    print('=====================================');
  }

  void dispose() {
    if (!kIsWeb) {
      _razorpay?.clear();
    }
  }
}
