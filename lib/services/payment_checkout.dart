import 'payment_checkout_api.dart';
import 'payment_checkout_native.dart'
    if (dart.library.js_interop) 'payment_checkout_web.dart'
    as platform;

export 'payment_checkout_api.dart';

PaymentCheckout createPaymentCheckout({
  required PaymentCheckoutSuccess onSuccess,
  required PaymentCheckoutFailure onFailure,
  required PaymentCheckoutDismissed onDismissed,
  required PaymentCheckoutExternalWallet onExternalWallet,
}) {
  return platform.createPaymentCheckout(
    onSuccess: onSuccess,
    onFailure: onFailure,
    onDismissed: onDismissed,
    onExternalWallet: onExternalWallet,
  );
}
