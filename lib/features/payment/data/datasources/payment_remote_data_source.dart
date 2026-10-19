import '../../../../core/error/failure.dart';

/// What a consultation costs, priced by the server.
///
/// The platform fee and the doctor's own fee arrive together because they are
/// one answer to one question. The app used to ask only for the platform fee
/// and add it to a figure off a doctor listing, which meant the total on the
/// screen and the total that would be charged were computed in two places with
/// nothing keeping them equal.
class PaymentQuote {
  const PaymentQuote({
    this.consultationFee,
    required this.platformFee,
    this.keyId,
    this.isTestMode = false,
  });

  /// The doctor's fee in whole rupees, or null when the server did not price it
  /// — which is the simulated path, where the doctor entity's own figure stands
  /// in. Null rather than a guess: a fabricated fee that looks authoritative is
  /// worse than an obvious fallback.
  final int? consultationFee;

  final int platformFee;

  /// The Razorpay key id to open checkout with.
  ///
  /// Served rather than read from the build, so rotating a key or moving from
  /// test to live needs no app release. [AppConfig.razorpayKeyId] remains the
  /// fallback for when this call could not be made.
  final String? keyId;

  /// True while a `rzp_test_…` key is in use, so the screen can say out loud
  /// that no money will move.
  final bool isTestMode;
}

/// A Razorpay order, created server-side, that checkout is opened against.
///
/// The `orderId` is the whole reason this round trip exists. With one, Razorpay
/// charges what the order says and ignores the figure the handset passes to the
/// SDK; without one, checkout bills whatever the app asked for — and a patched
/// build asks for a rupee.
class PaymentOrder {
  const PaymentOrder({
    required this.orderId,
    required this.amountInRupees,
    required this.keyId,
    this.isTestMode = false,
  });

  final String orderId;

  /// What the server decided this costs. Shown and charged; if it disagrees
  /// with the summary on screen, this is the figure that is true.
  final int amountInRupees;

  final String keyId;
  final bool isTestMode;
}

/// Talks to the payment API.
abstract interface class PaymentRemoteDataSource {
  /// What a consultation with [doctorId] in [mode] costs.
  Future<PaymentQuote> fetchQuote({
    required String doctorId,
    required String mode,
  });

  /// Creates the order to open checkout against.
  ///
  /// [consultationId] is set for a booked appointment, whose slot is held
  /// before payment, and absent for an instant consultation, which has no row
  /// until a doctor answers.
  Future<PaymentOrder> createOrder({
    required String doctorId,
    required String mode,
    String? consultationId,
  });

  /// Hands the checkout result to the server, which recomputes the signature.
  ///
  /// Returns the confirmed Razorpay payment id. Throws when the signature does
  /// not verify — which the app must treat as a failed payment however cheerful
  /// the SDK's callback was, because the callback is a message from a client
  /// and this is the check.
  Future<String> confirmPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    String? consultationId,
  });

  Future<String> verifyUpiId(String upiId);

  /// Records a charge on the simulated path, where no gateway is configured.
  Future<String> charge({required int amount, required String method});
}

/// Stand-in for a build with no API, and for tests.
///
/// Says yes to everything. It cannot price a consultation — only the server
/// knows a doctor's fee — so [fetchQuote] returns a null consultation fee and
/// lets the caller fall back to the doctor entity.
class FakePaymentRemoteDataSource implements PaymentRemoteDataSource {
  const FakePaymentRemoteDataSource();

  static const _latency = Duration(milliseconds: 600);

  /// Addresses at this handle are treated as unknown, so the failure path
  /// stays exercisable in development and tests.
  static const unknownHandle = '@unknown';

  @override
  Future<PaymentQuote> fetchQuote({
    required String doctorId,
    required String mode,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const PaymentQuote(platformFee: 50);
  }

  @override
  Future<PaymentOrder> createOrder({
    required String doctorId,
    required String mode,
    String? consultationId,
  }) async {
    // Nothing to open an order against. The simulated gateway does not read it,
    // and the repository does not ask for one when the gateway is not live.
    throw const Failure('Online payment is not configured in this build.');
  }

  @override
  Future<String> confirmPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    String? consultationId,
  }) async => paymentId;

  @override
  Future<String> verifyUpiId(String upiId) async {
    await Future<void>.delayed(_latency);

    if (upiId.endsWith(unknownHandle)) {
      throw const Failure('We could not find that UPI ID.');
    }

    // The gateway echoes back the registered account holder.
    final handle = upiId.split('@').first.replaceAll(RegExp(r'[._-]'), ' ');
    return handle
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  @override
  Future<String> charge({required int amount, required String method}) async {
    await Future<void>.delayed(_latency);
    return 'txn_${method}_$amount';
  }
}
