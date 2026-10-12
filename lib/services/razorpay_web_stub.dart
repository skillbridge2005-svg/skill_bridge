Future<void> openRazorpayWeb({
  required Map<String, dynamic> options,
  required Future<void> Function(
    String? paymentId,
    String? orderId,
    String? signature,
  )
  onSuccess,
}) async {
  throw UnsupportedError('Razorpay Web is not available on this platform.');
}
