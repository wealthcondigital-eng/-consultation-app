import '../../../../core/error/failure.dart';

/// What the gateway hands back when the patient has paid.
class GatewayPayment {
  const GatewayPayment({required this.paymentId, this.orderId, this.signature});

  /// Razorpay's own id for the payment, e.g. `pay_MkT7…`. Kept as the
  /// transaction reference the receipt shows and support quotes.
  final String paymentId;

  /// The order this settles, when one was created server-side.
  final String? orderId;

  /// Razorpay's HMAC over `orderId|paymentId`.
  ///
  /// **The app cannot check this.** Verifying it needs the key secret, and a
  /// secret compiled into an APK is a secret anybody can read out of the APK —
  /// at which point they can forge a signature and the check proves nothing.
  /// It is carried out of here so the server can verify it, which is the only
  /// place the answer means anything.
  final String? signature;
}

/// Collects money for a consultation.
///
/// An interface rather than a direct call into the SDK, for two reasons that
/// both bit this codebase before: a widget test has no Razorpay activity to
/// open, and a build with no key configured still has to walk the booking flow
/// end to end. Both get a stand-in; only a real build gets the real sheet.
abstract interface class PaymentGateway {
  /// False when no key is configured, which the payment screen says out loud
  /// rather than pretending a charge happened.
  bool get isLive;

  /// True when the gateway asks for the payment method inside its own sheet,
  /// so the app must not ask as well.
  ///
  /// A property of the gateway rather than of the build's configuration, and
  /// the distinction matters: the screen has to follow whichever gateway is
  /// actually in use. Reading it off a compile-time constant meant a build with
  /// a key configured hid the picker even where the simulated gateway was the
  /// one that would run — which is the picker hidden and nothing put in its
  /// place, the exact shape of the dead end this once produced.
  bool get collectsMethodItself;

  /// Opens checkout and completes when the patient has paid.
  ///
  /// Throws a [Failure] if they cancel or the payment fails — cancelling is
  /// not an error worth a red screen, but it is emphatically not a success, and
  /// the booking must not be filed behind it.
  ///
  /// [keyId] overrides the key compiled into the build when the server named
  /// one on the order. That is what makes rotating a key, or switching the
  /// platform from test to live, a server change rather than a release — the
  /// build's own key stays as the fallback for when the order call could not
  /// be made at all.
  Future<GatewayPayment> collect({
    required int amountInRupees,
    required String description,
    String? contact,
    String? email,
    String? orderId,
    String? keyId,
  });

  void dispose();
}

/// The stand-in used when no key is configured, and in tests.
///
/// Says yes after a beat. Deliberately not wired to the UPI-id validation the
/// old flow used: that was a fake gateway pretending to be a real one, and the
/// two are worth telling apart.
class SimulatedPaymentGateway implements PaymentGateway {
  const SimulatedPaymentGateway();

  @override
  bool get isLive => false;

  /// False: the stand-in has no sheet of its own, so the app's own picker is
  /// the only thing that can ask.
  @override
  bool get collectsMethodItself => false;

  @override
  Future<GatewayPayment> collect({
    required int amountInRupees,
    required String description,
    String? contact,
    String? email,
    String? orderId,
    String? keyId,
  }) async {
    // No delay of its own. The charge behind it already simulates a gateway's
    // latency, and two stand-ins each waiting their turn makes a keyless build
    // feel twice as slow as the real thing.
    return GatewayPayment(
      paymentId: 'sim_${DateTime.now().millisecondsSinceEpoch}',
      orderId: orderId,
    );
  }

  @override
  void dispose() {}
}

/// Stands in on a **live** build that has no gateway configured, and refuses.
///
/// The thing it replaces was [SimulatedPaymentGateway], and that substitution
/// was the most expensive line in this feature. A live build with no key fell
/// back to the stand-in, the stand-in said "paid" after no delay at all, and the
/// flow believed it: the slot was booked, the confirmation was written and the
/// patient's phone buzzed to say their consultation was booked — with no sheet,
/// no money and nothing to refund, because nothing had been charged. From the
/// outside it looked like Razorpay failing to open. It was worse than that; it
/// was the app giving consultations away.
///
/// A stand-in is right where nothing real can run: a widget test has no activity
/// for the SDK to open, and a fake-backend build has no server to create an
/// order against. It is wrong on a build pointed at a real API and real doctors,
/// where "I could not take the payment" is the only honest answer and a refusal
/// the patient can read beats a booking nobody paid for.
///
/// [isLive] is true on purpose. It is what keeps [PaymentRepositoryImpl] off the
/// simulated branch — which would call `charge()` and hand back a reference, and
/// so reintroduce the very bug this class exists to prevent.
class UnconfiguredPaymentGateway implements PaymentGateway {
  const UnconfiguredPaymentGateway();

  @override
  bool get isLive => true;

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
    throw const Failure(
      'Online payment is not set up in this build, so this consultation '
      'cannot be paid for. Please contact support.',
      code: 'gateway_not_configured',
    );
  }

  @override
  void dispose() {}
}

/// Raised when the patient closed the sheet without paying.
///
/// Its own message because the alternative wording — "payment failed" — is
/// wrong and alarming for someone who simply changed their mind.
const cancelledPayment = Failure(
  'Payment was cancelled. Your appointment has not been booked.',
  code: 'payment_cancelled',
);
