import '../../../../core/error/failure.dart';
import '../../../../core/logging/auth_logger.dart';
import '../../../../core/network/api_client.dart';
import 'payment_remote_data_source.dart';

/// Payments, on the consultation API.
///
/// Three routes, and the division of labour between them is the point of the
/// whole design:
///
///  * `GET  /payments/quote`  — the server prices the consultation. The app
///                              displays the answer; it does not compute one.
///  * `POST /payments/order`  — the server creates the Razorpay order. **No
///                              amount is sent.** The order fixes the sum, so
///                              a patched build cannot ask for a rupee.
///  * `POST /payments/verify` — the server recomputes the checkout HMAC. Until
///                              this answers, a successful payment is only a
///                              claim the handset is making about itself.
///
/// UPI-id verification is still the stand-in's: there is no server route for it
/// and, with Razorpay collecting the method inside its own sheet, no screen
/// that reaches it either.
class ApiPaymentRemoteDataSource implements PaymentRemoteDataSource {
  const ApiPaymentRemoteDataSource(this._api);

  final ApiClient _api;

  @override
  Future<PaymentQuote> fetchQuote({
    required String doctorId,
    required String mode,
  }) async {
    final json = await _api.get(
      '/payments/quote?doctorId=$doctorId&mode=$mode',
    );
    final quote = json['quote'];
    if (quote is! Map) throw const Failure.unexpected();

    return PaymentQuote(
      consultationFee: _asInt(quote['consultationFee']),
      // Falls back rather than failing: a missing platform fee should not stop
      // a consultation being paid for, and zero is the honest reading of a
      // server that did not name one.
      platformFee: _asInt(quote['platformFee']) ?? 0,
      keyId: quote['keyId'] as String?,
      isTestMode: quote['isTestMode'] == true,
    );
  }

  @override
  Future<PaymentOrder> createOrder({
    required String doctorId,
    required String mode,
    String? consultationId,
  }) async {
    final json = await _api.post(
      '/payments/order',
      body: {
        'doctorId': doctorId,
        'mode': mode,
        'consultationId': ?consultationId,
        // Deliberately no amount. See the class comment: the server prices this
        // from the doctor's own record, and anything the app sent would be a
        // number a patched build gets to choose.
      },
    );

    final order = json['order'];
    if (order is! Map) throw const Failure.unexpected();

    final orderId = order['orderId'];
    final keyId = order['keyId'];
    final total = _asInt(order['total']);

    if (orderId is! String || keyId is! String || total == null) {
      throw const Failure('Payment could not be started. Please try again.');
    }

    AuthLogger.event('PAYMENT · order created', {
      'order': orderId,
      'amount': '₹$total',
      'mode': order['isTestMode'] == true ? 'test' : 'live',
    });

    return PaymentOrder(
      orderId: orderId,
      amountInRupees: total,
      keyId: keyId,
      isTestMode: order['isTestMode'] == true,
    );
  }

  @override
  Future<String> confirmPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    String? consultationId,
  }) async {
    final json = await _api.post(
      '/payments/verify',
      body: {
        'razorpayOrderId': orderId,
        'razorpayPaymentId': paymentId,
        'razorpaySignature': signature,
        'consultationId': ?consultationId,
      },
    );

    final payment = json['payment'];
    final confirmed = payment is Map ? payment['paymentId'] : null;

    if (confirmed is! String || confirmed.isEmpty) {
      // The server answered without confirming. Treated as a failure rather
      // than shrugged off: the alternative is a consultation that goes ahead on
      // the strength of a response nobody checked.
      throw const Failure(
        'We could not confirm your payment. If money has left your account it '
        'will be returned automatically.',
      );
    }

    AuthLogger.event('PAYMENT · verified by server', {
      'paymentId': confirmed,
      'status': payment is Map ? payment['status'] ?? '(none)' : '(none)',
    });

    return confirmed;
  }

  @override
  Future<String> verifyUpiId(String upiId) =>
      const FakePaymentRemoteDataSource().verifyUpiId(upiId);

  @override
  Future<String> charge({required int amount, required String method}) =>
      const FakePaymentRemoteDataSource().charge(
        amount: amount,
        method: method,
      );
}

/// JSON numbers arrive as `int` or `double` depending on how they were written,
/// and a fee of `800.0` must not become null on the way in.
int? _asInt(Object? value) => switch (value) {
  final int value => value,
  final num value => value.round(),
  final String value => int.tryParse(value),
  _ => null,
};
