import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/logging/auth_logger.dart';
import 'payment_gateway.dart';

/// Pays through a Razorpay **payment link** opened in an in-app browser.
///
/// The fallback for when there is a link but no checkout key — and a deliberate
/// second choice, for two reasons worth knowing before switching to it:
///
///  * **A link carries its own amount.** It is created for a fixed sum and a
///    named customer, so one link cannot bill ₹850 for a cardiologist and ₹500
///    for a dentist. Billing per consultation means creating a link per
///    booking through Razorpay's API, which needs the key secret and therefore
///    a server. Until then this charges whatever the link was made for,
///    regardless of what the app's summary says — which is why it refuses to
///    run unless the link is explicitly configured.
///  * **Nothing comes back.** The browser knows the payment succeeded; the app
///    does not. There is no callback, no payment id and no signature, so the
///    only honest confirmation is a webhook to your server. The app cannot tell
///    "paid" from "closed the tab", and it does not pretend to.
///
/// It opens in an **in-app browser** — Chrome Custom Tabs on Android, Safari
/// View Controller on iOS — rather than a `WebView`. That distinction is the
/// whole reason this is usable at all: UPI payment means handing off to GPay or
/// PhonePe through an intent, and a bare `WebView` cannot do it. A Custom Tab
/// can, and brings the patient back afterwards.
class PaymentLinkGateway implements PaymentGateway {
  const PaymentLinkGateway({String? link})
    : _link = link ?? AppConfig.razorpayPaymentLink;

  final String _link;

  @override
  bool get isLive => _link.isNotEmpty;

  /// The hosted page asks for the method, same as checkout does.
  @override
  bool get collectsMethodItself => true;

  @override
  Future<GatewayPayment> collect({
    required int amountInRupees,
    required String description,
    String? contact,
    String? email,
    String? orderId,
    String? keyId,
  }) async {
    final uri = Uri.tryParse(_link);
    if (!isLive || uri == null) {
      throw const Failure('No payment link is configured in this build.');
    }

    AuthLogger.event('PAYMENT · opening payment link', {
      'link': _link,
      'app is charging': '₹$amountInRupees',
      'link will charge': 'whatever it was created for',
    });

    final opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    if (!opened) {
      throw const Failure('Could not open the payment page.');
    }

    // Deliberately no payment id: the app never learns one. The reference is
    // marked so nothing downstream mistakes it for a verified Razorpay payment.
    return GatewayPayment(
      paymentId: 'link_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  @override
  void dispose() {}
}
