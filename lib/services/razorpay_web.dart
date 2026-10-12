import 'dart:convert';
import 'dart:js_interop';

@JS('openRazorpayCheckout')
external void openRazorpayCheckout(String optionsJson, JSFunction onSuccess);

Future<void> openRazorpayWeb({
  required Map<String, dynamic> options,
  required Future<void> Function(
    String? paymentId,
    String? orderId,
    String? signature,
  )
  onSuccess,
}) async {
  final callback = (JSString paymentId, JSString orderId, JSString signature) {
    onSuccess(paymentId.toDart, orderId.toDart, signature.toDart);
  }.toJS;

  openRazorpayCheckout(jsonEncode(options), callback);
}
