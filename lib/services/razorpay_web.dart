import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

@JS('openRazorpayCheckout')
external void openRazorpayCheckout(
  JSString optionsJson,
  JSFunction onSuccess,
  JSFunction onFailure,
  JSFunction onDismissed,
);

Future<void> openRazorpayWeb({
  required Map<String, dynamic> options,
  required Future<void> Function(
    String? paymentId,
    String? orderId,
    String? signature,
  )
  onSuccess,
}) async {
  final callback = (JSString responseJson) {
    final response = jsonDecode(responseJson.toDart) as Map<String, dynamic>;
    onSuccess(
      response['razorpay_payment_id'] as String?,
      response['razorpay_order_id'] as String?,
      response['razorpay_signature'] as String?,
    );
  }.toJS;

  final failureCallback = (JSString errorJson) {
    final error = jsonDecode(errorJson.toDart) as Map<String, dynamic>;
    debugPrint(
      'Razorpay payment failed: '
      '${error['description'] ?? error['reason']}',
    );
  }.toJS;
  final dismissedCallback = (() {
    debugPrint('Razorpay checkout dismissed.');
  }).toJS;

  openRazorpayCheckout(
    jsonEncode(options).toJS,
    callback,
    failureCallback,
    dismissedCallback,
  );
}
