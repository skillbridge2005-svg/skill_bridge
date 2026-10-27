typedef PaymentCheckoutSuccess = Future<void> Function({
  required String paymentId,
  required String orderId,
  required String signature,
});

typedef PaymentCheckoutFailure = void Function(String message);
typedef PaymentCheckoutDismissed = void Function();
typedef PaymentCheckoutExternalWallet = void Function(String walletName);

abstract class PaymentCheckout {
  void open(Map<String, dynamic> options);

  void dispose();
}
