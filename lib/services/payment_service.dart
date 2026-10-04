import 'package:cloud_functions/cloud_functions.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentService {
  final Razorpay _razorpay = Razorpay();

  PaymentService() {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);

    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);

    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  Future<void> startPayment({
    required double amount,
    required String projectId,
    required String email,
    String? contact,
  }) async {
    try {
      // Connect to Firebase Functions
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');

      // Call createRazorpayOrder Firebase Function
      final callable = functions.httpsCallable('createRazorpayOrder');

      final result = await callable.call({
        'amount': amount,
        'projectId': projectId,
      });

      final data = Map<String, dynamic>.from(result.data);

      final String orderId = data['orderId'];
      final String keyId = data['keyId'];
      final int amountInPaise = data['amount'];

      // Razorpay Checkout configuration
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

      // Open Razorpay Checkout
      _razorpay.open(options);
    } catch (e) {
      print('Payment initialization failed: $e');
      rethrow;
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print('========== PAYMENT SUCCESS ==========');
    print('Payment ID: ${response.paymentId}');
    print('Order ID: ${response.orderId}');
    print('Signature: ${response.signature}');
    print('=====================================');

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('verifyRazorpayPayment');

      final result = await callable.call({
        'razorpayOrderId': response.orderId,
        'razorpayPaymentId': response.paymentId,
        'razorpaySignature': response.signature,
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
    _razorpay.clear();
  }
}
