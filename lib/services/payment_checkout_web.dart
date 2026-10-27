import 'dart:convert';
import 'dart:js_interop';

import 'payment_checkout_api.dart';

@JS('openRazorpayCheckout')
external void _openRazorpayCheckout(
  JSString optionsJson,
  JSFunction onSuccess,
  JSFunction onFailure,
  JSFunction onDismissed,
);

PaymentCheckout createPaymentCheckout({
  required PaymentCheckoutSuccess onSuccess,
  required PaymentCheckoutFailure onFailure,
  required PaymentCheckoutDismissed onDismissed,
  required PaymentCheckoutExternalWallet onExternalWallet,
}) {
  return _WebPaymentCheckout(
    onSuccess: onSuccess,
    onFailure: onFailure,
    onDismissed: onDismissed,
    onExternalWallet: onExternalWallet,
  );
}

class _WebPaymentCheckout implements PaymentCheckout {
  _WebPaymentCheckout({
    required this.onSuccess,
    required this.onFailure,
    required this.onDismissed,
    required this.onExternalWallet,
  });

  final PaymentCheckoutSuccess onSuccess;
  final PaymentCheckoutFailure onFailure;
  final PaymentCheckoutDismissed onDismissed;
  final PaymentCheckoutExternalWallet onExternalWallet;

  @override
  void open(Map<String, dynamic> options) {
    final successCallback = (JSString resultJson) {
      final result = jsonDecode(resultJson.toDart) as Map<String, dynamic>;
      onSuccess(
        paymentId: result['razorpay_payment_id'] as String? ?? '',
        orderId: result['razorpay_order_id'] as String? ?? '',
        signature: result['razorpay_signature'] as String? ?? '',
      );
    }.toJS;

    final failureCallback = (JSString errorJson) {
      final error = jsonDecode(errorJson.toDart) as Map<String, dynamic>;
      final description =
          (error['description'] ?? error['reason'] ?? 'Payment failed')
              .toString();
      onFailure(description);
    }.toJS;

    final dismissedCallback = (() {
      onDismissed();
    }).toJS;

    _openRazorpayCheckout(
      jsonEncode(options).toJS,
      successCallback,
      failureCallback,
      dismissedCallback,
    );
  }

  @override
  void dispose() {}
}
