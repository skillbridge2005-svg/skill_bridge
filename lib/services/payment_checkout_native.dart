import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'payment_checkout_api.dart';

PaymentCheckout createPaymentCheckout({
  required PaymentCheckoutSuccess onSuccess,
  required PaymentCheckoutFailure onFailure,
  required PaymentCheckoutDismissed onDismissed,
  required PaymentCheckoutExternalWallet onExternalWallet,
}) {
  return _NativePaymentCheckout(
    onSuccess: onSuccess,
    onFailure: onFailure,
    onExternalWallet: onExternalWallet,
  );
}

class _NativePaymentCheckout implements PaymentCheckout {
  _NativePaymentCheckout({
    required this.onSuccess,
    required this.onFailure,
    required this.onExternalWallet,
  }) {
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handleFailure);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  final PaymentCheckoutSuccess onSuccess;
  final PaymentCheckoutFailure onFailure;
  final PaymentCheckoutExternalWallet onExternalWallet;
  final Razorpay _razorpay = Razorpay();

  void _handleSuccess(PaymentSuccessResponse response) {
    final paymentId = response.paymentId;
    final orderId = response.orderId;
    final signature = response.signature;

    if (paymentId == null || orderId == null || signature == null) {
      onFailure('Razorpay returned incomplete payment details.');
      return;
    }

    onSuccess(paymentId: paymentId, orderId: orderId, signature: signature);
  }

  void _handleFailure(PaymentFailureResponse response) {
    onFailure(response.message ?? 'Payment failed or was cancelled.');
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    onExternalWallet(response.walletName ?? 'Wallet');
  }

  @override
  void open(Map<String, dynamic> options) {
    _razorpay.open(options);
  }

  @override
  void dispose() {
    _razorpay.clear();
  }
}
