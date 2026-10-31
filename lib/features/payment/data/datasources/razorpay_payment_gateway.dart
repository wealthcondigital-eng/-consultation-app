import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/branding/app_brand.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../../../core/session/auth_session.dart';
import 'payment_gateway.dart';

/// Razorpay's native checkout.
///
/// Chosen over opening a payment link in a web view, and the reason is UPI. On
/// a phone, paying by UPI means handing off to GPay, PhonePe or Paytm through
/// an Android intent and being handed back. The native SDK does that; a page
/// inside a `WebView` cannot — the intent either does nothing or leaves the
/// patient stranded in a browser with no way back into the app, which is the
/// single most common way a checkout loses a payment in India. The SDK also
/// brings saved cards and the retry UI for free.
///
/// **This class is one third of the flow, and the weakest third.** It opens a
/// sheet and reports what came back; it proves nothing. The other two thirds
/// are on the server and are what make the result trustworthy:
///
///  * the **order** is created by `POST /payments/order` before this is called,
///    and passed in as [orderId]. It is what fixes the amount — with one,
///    Razorpay charges what the order says and ignores the figure passed to
///    `open` below. Without one, checkout bills whatever this process asked
///    for, and a patched build asks for a rupee.
///  * the **signature** handed back on success is checked by
///    `POST /payments/verify`, which holds the key secret. Until that answers,
///    a success callback is a message from a client, and a client can say
///    anything. See [GatewayPayment.signature].
///
/// So a payment is not "done" when this future completes. It is done when the
/// server says so — which is why [PaymentRepositoryImpl] calls verify before
/// reporting success to anything above it.
class RazorpayPaymentGateway implements PaymentGateway {
  RazorpayPaymentGateway(this._session, {String? keyId})
    : _keyId = keyId ?? AppConfig.razorpayKeyId;

  final String _keyId;

  /// Prefills the phone number checkout would otherwise ask for. The patient
  /// verified it to get in; asking again at the moment of payment is friction
  /// at the worst possible point in the flow.
  final AuthSession _session;

  Razorpay? _razorpay;

  /// The payment in flight. The SDK reports through callbacks rather than
  /// returning a future, so the call is bridged to one here — and only ever one
  /// at a time, because checkout is a full-screen activity.
  Completer<GatewayPayment>? _pending;

  @override
  bool get isLive => _keyId.isNotEmpty;

  /// UPI, cards, saved cards and the UPI-app handoff are all inside
  /// Razorpay's own sheet. Asking in the app as well is the same question
  /// twice, and the answer given here is thrown away by the one that follows.
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
  }) {
    // The server's key wins where it named one. It travels with the order, so
    // the key that opens checkout and the key the order was created under are
    // the same key by construction — which they would not be if the build kept
    // using its own after the account rotated one.
    final key = (keyId != null && keyId.isNotEmpty) ? keyId : _keyId;

    if (key.isEmpty) {
      throw const Failure(
        'Payments are not configured in this build. '
        'Rebuild with --dart-define=RAZORPAY_KEY_ID=…',
      );
    }
    if (_pending != null && !_pending!.isCompleted) {
      throw const Failure('A payment is already in progress.');
    }

    final razorpay = _razorpay ??= Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);

    final completer = _pending = Completer<GatewayPayment>();

    AuthLogger.event('PAYMENT · opening checkout', {
      'amount': '₹$amountInRupees',
      'mode': key.startsWith('rzp_test') ? 'test' : 'live',
      // An order is what fixes the amount at Razorpay's end. Without one the
      // sheet bills whatever this call asked for, which is a figure a patched
      // build gets to choose — so its absence is worth seeing in the log.
      'order': orderId ?? '(none — amount only, NOT production-safe)',
    });

    razorpay.open({
      'key': key,
      // Razorpay counts in paise. Sending rupees here is the classic way to
      // charge a hundredth of the fee and not notice until settlement.
      'amount': amountInRupees * 100,
      'currency': 'INR',
      'name': AppBrand.name,
      'description': description,
      'order_id': ?orderId,
      'prefill': {
        if ((contact ?? _session.phone) case final number?
            when number.isNotEmpty)
          'contact': number,
        if (email != null && email.isNotEmpty) 'email': email,
      },
      'theme': {'color': '#1B7B80'},
      // A consultation is booked against a slot that is held while the patient
      // pays. Letting checkout sit open indefinitely would hold it all day.
      'timeout': 300,
      'retry': {'enabled': true, 'max_count': 1},
      // UPI and cards only. Netbanking and wallets are hidden from the sheet;
      // `config.display.hide` is Razorpay's current switch and `method` the
      // older one, and the Android SDK has honoured each at different times.
      'method': {'netbanking': false, 'wallet': false},
      'config': {
        'display': {
          'hide': [
            {'method': 'netbanking'},
            {'method': 'wallet'},
          ],
          'preferences': {'show_default_blocks': true},
        },
      },
    });

    return completer.future;
  }

  void _onSuccess(PaymentSuccessResponse response) {
    AuthLogger.event('PAYMENT · succeeded', {
      'paymentId': response.paymentId,
      'orderId': response.orderId ?? '(none)',
      'verified': 'no — the server must check the signature',
    });

    _finish(
      GatewayPayment(
        paymentId: response.paymentId ?? 'unknown',
        orderId: response.orderId,
        signature: response.signature,
      ),
    );
  }

  void _onError(PaymentFailureResponse response) {
    AuthLogger.event('PAYMENT · failed', {
      'code': response.code ?? '(none)',
      'message': response.message ?? '(none)',
    });

    // Razorpay reports a closed sheet as an error with this code. It is not a
    // failure from the patient's side — they changed their mind — and telling
    // them their payment failed would be both wrong and alarming.
    if (response.code == Razorpay.PAYMENT_CANCELLED) {
      _fail(cancelledPayment);
      return;
    }

    _fail(
      Failure(
        _readable(response.message) ??
            'The payment could not be completed. Please try again.',
      ),
    );
  }

  /// Paytm and the other wallets that leave the app to finish. Razorpay tells
  /// the app the wallet was chosen, not that it was paid — the outcome arrives
  /// on the normal callbacks afterwards, so there is nothing to complete here.
  void _onExternalWallet(ExternalWalletResponse response) {
    AuthLogger.event('PAYMENT · handed to wallet', {
      'wallet': response.walletName ?? '(unknown)',
    });
  }

  /// Razorpay's messages are sometimes a JSON blob rather than a sentence, and
  /// a raw `{"error":{"code":…}}` in a snackbar helps nobody.
  static String? _readable(String? message) {
    if (message == null || message.isEmpty) return null;
    if (message.trimLeft().startsWith('{')) return null;
    return message;
  }

  void _finish(GatewayPayment payment) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) pending.complete(payment);
  }

  void _fail(Failure failure) {
    final pending = _pending;
    _pending = null;
    if (pending != null && !pending.isCompleted) {
      pending.completeError(failure);
    }
  }

  @override
  void dispose() {
    // Leaks a native listener otherwise, and the next checkout then reports to
    // a controller that is gone.
    _razorpay?.clear();
    _razorpay = null;
    _fail(cancelledPayment);
  }
}
