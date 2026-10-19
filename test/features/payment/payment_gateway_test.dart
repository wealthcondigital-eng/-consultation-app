import 'package:consultation_app/core/config/app_config.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:consultation_app/features/payment/data/datasources/payment_gateway.dart';
import 'package:consultation_app/features/payment/data/datasources/payment_remote_data_source.dart';
import 'package:consultation_app/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:consultation_app/features/payment/domain/entities/fee_breakdown.dart';
import 'package:consultation_app/features/payment/domain/entities/payment_method.dart';
import 'package:consultation_app/features/payment/domain/entities/payment_summary.dart';
import 'package:flutter_test/flutter_test.dart';

const _summary = PaymentSummary(
  doctor: Doctor(
    id: 'amit-verma',
    name: 'Dr. Amit Verma',
    speciality: 'Senior Cardiologist',
    yearsOfExperience: 15,
    rating: 4.9,
    consultationFee: 800,
  ),
  mode: ConsultationMode.video,
  fees: FeeBreakdown(consultationFee: 800, platformFee: 50),
);

/// Stands in for Razorpay: records what it was asked to charge, and answers
/// with whatever the test set up.
class _RecordingGateway implements PaymentGateway {
  _RecordingGateway({this.failure, this.omitSignature = false});

  final Failure? failure;

  /// Answers a success with no signature on it, which is what a checkout opened
  /// without an order does — and which nothing downstream can verify.
  final bool omitSignature;

  int? chargedRupees;
  String? description;
  String? openedWithOrderId;
  String? openedWithKeyId;
  var disposed = false;

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
    chargedRupees = amountInRupees;
    this.description = description;
    openedWithOrderId = orderId;
    openedWithKeyId = keyId;

    if (failure case final failure?) throw failure;

    return GatewayPayment(
      paymentId: 'pay_TEST123',
      orderId: orderId,
      signature: omitSignature ? null : 'a' * 64,
    );
  }

  @override
  void dispose() => disposed = true;
}

/// Stands in for the API: prices the consultation, issues an order, and
/// verifies what checkout handed back.
class _RecordingApi implements PaymentRemoteDataSource {
  _RecordingApi({this.orderAmount = 850});

  /// What the *server* says this costs. Deliberately settable apart from the
  /// summary, so a test can make the two disagree.
  final int orderAmount;

  String? orderedForDoctor;
  String? orderedForMode;
  String? orderedForConsultation;
  var orderCount = 0;

  String? confirmedOrderId;
  String? confirmedPaymentId;
  String? confirmedConsultationId;
  var confirmCount = 0;

  @override
  Future<PaymentQuote> fetchQuote({
    required String doctorId,
    required String mode,
  }) async => const PaymentQuote(consultationFee: 800, platformFee: 50);

  @override
  Future<PaymentOrder> createOrder({
    required String doctorId,
    required String mode,
    String? consultationId,
  }) async {
    orderCount++;
    orderedForDoctor = doctorId;
    orderedForMode = mode;
    orderedForConsultation = consultationId;

    return PaymentOrder(
      orderId: 'order_TEST999',
      amountInRupees: orderAmount,
      keyId: 'rzp_test_FROM_SERVER',
    );
  }

  @override
  Future<String> confirmPayment({
    required String orderId,
    required String paymentId,
    required String signature,
    String? consultationId,
  }) async {
    confirmCount++;
    confirmedOrderId = orderId;
    confirmedPaymentId = paymentId;
    confirmedConsultationId = consultationId;
    return 'pay_CONFIRMED';
  }

  @override
  Future<String> verifyUpiId(String upiId) async => 'Anita Desai';

  @override
  Future<String> charge({required int amount, required String method}) async =>
      'txn_local';
}

PaymentRepositoryImpl _repository(
  PaymentGateway gateway, {
  PaymentRemoteDataSource? api,
}) => PaymentRepositoryImpl(api ?? _RecordingApi(), gateway);

void main() {
  group('paying through a real gateway', () {
    test('creates the order before opening checkout', () async {
      // The order is what fixes the amount at Razorpay's end. Opening checkout
      // without one bills whatever this process asked for, which is a figure a
      // patched build gets to choose.
      final gateway = _RecordingGateway();
      final api = _RecordingApi();

      await _repository(
        gateway,
        api: api,
      ).pay(summary: _summary, method: PaymentMethod.card);

      expect(api.orderCount, 1);
      expect(gateway.openedWithOrderId, 'order_TEST999');
      expect(api.orderedForDoctor, 'amit-verma');
      expect(api.orderedForMode, 'video');
    });

    test('charges the amount the server priced, not the one on screen', () async {
      // The security property the whole round trip exists for. The summary here
      // claims ₹850; the server says ₹1200, and the server wins — because a
      // build whose fee screen has been patched would claim one rupee, and a
      // flow that trusted the screen would charge it.
      final gateway = _RecordingGateway();

      await _repository(
        gateway,
        api: _RecordingApi(orderAmount: 1200),
      ).pay(summary: _summary, method: PaymentMethod.card);

      expect(gateway.chargedRupees, 1200);
      expect(gateway.description, contains('Dr. Amit Verma'));
    });

    test('opens checkout with the key the order came back with', () async {
      // So rotating a key, or moving the platform to live, is a server change
      // rather than an app release.
      final gateway = _RecordingGateway();

      await _repository(
        gateway,
      ).pay(summary: _summary, method: PaymentMethod.card);

      expect(gateway.openedWithKeyId, 'rzp_test_FROM_SERVER');
    });

    test('hands back the reference the server confirmed', () async {
      // Not the one the SDK reported. The SDK's is a claim made by this
      // process; the server's is the one that survived a signature check.
      final api = _RecordingApi();

      final reference = await _repository(
        _RecordingGateway(),
        api: api,
      ).pay(summary: _summary, method: PaymentMethod.card);

      expect(reference, 'pay_CONFIRMED');
      expect(api.confirmCount, 1);
      expect(api.confirmedOrderId, 'order_TEST999');
      expect(api.confirmedPaymentId, 'pay_TEST123');
    });

    test('carries the booking through to verification', () async {
      // So the server can mark the held slot paid. Without it a booking and an
      // abandoned hold are the same row on the doctor's diary.
      final api = _RecordingApi();

      await _repository(_RecordingGateway(), api: api).pay(
        summary: _summary,
        method: PaymentMethod.card,
        consultationId: 'consult-77',
      );

      expect(api.orderedForConsultation, 'consult-77');
      expect(api.confirmedConsultationId, 'consult-77');
    });

    test('a success with no signature is not treated as paid', () async {
      // There is nothing to verify, so there is nothing to believe. Reporting
      // this as a payment would let a consultation go ahead on the strength of
      // a callback nobody could check.
      final api = _RecordingApi();

      await expectLater(
        _repository(
          _RecordingGateway(omitSignature: true),
          api: api,
        ).pay(summary: _summary, method: PaymentMethod.card),
        throwsA(isA<Failure>()),
      );

      expect(api.confirmCount, 0);
    });

    test('a cancelled payment does not read as a failure', () async {
      // The patient changed their mind. Telling them the payment failed is both
      // wrong and alarming.
      await expectLater(
        _repository(
          _RecordingGateway(failure: cancelledPayment),
        ).pay(summary: _summary, method: PaymentMethod.card),
        throwsA(
          isA<Failure>().having(
            (failure) => failure.message,
            'message',
            contains('cancelled'),
          ),
        ),
      );
    });

    test('a cancelled payment verifies nothing', () async {
      // Nothing is confirmed until the sheet has actually paid. A verification
      // filed behind a cancelled payment is a slot held for free.
      final api = _RecordingApi();

      await expectLater(
        _repository(
          _RecordingGateway(failure: cancelledPayment),
          api: api,
        ).pay(summary: _summary, method: PaymentMethod.card),
        throwsA(isA<Failure>()),
      );

      expect(api.confirmCount, 0);
    });
  });

  group('the method the app asks for', () {
    test('is decided by the gateway that will actually run', () {
      // The regression this guards, exactly as it reached a device: the picker
      // was hidden because Razorpay asks for the method itself, but the default
      // stayed UPI, UPI wants a UPI ID, and the only field for typing one had
      // just been removed. Pay went permanently grey and the flow dead-ended
      // with no sheet, no error and nothing to tap.
      //
      // Asked of the gateway rather than of the build's configuration, because
      // a build with a key configured still runs the stand-in under test — and
      // hiding the picker there hides it with nothing put in its place.
      expect(const SimulatedPaymentGateway().collectsMethodItself, isFalse);
      expect(_RecordingGateway().collectsMethodItself, isTrue);
    });

    test('a key ships by default, so checkout is what opens', () {
      // The bug this closes: with no key configured the payment screen fell
      // through to its own method picker and Razorpay never opened at all,
      // which from the outside looked exactly like a static page where a
      // payment sheet should have been.
      expect(AppConfig.hasPaymentGateway, isTrue);
    });

    test('card needs nothing typed in, so it can never block Pay', () {
      // Whatever the fallback method is, it must be one that needs no inline
      // detail — that is the whole property being relied on.
      expect(PaymentMethod.card.needsUpiId, isFalse);
      expect(PaymentMethod.netBanking.needsUpiId, isFalse);
      expect(PaymentMethod.upi.needsUpiId, isTrue);
    });
  });

  group('with no gateway configured', () {
    test('the booking flow still completes', () async {
      // A build with no Razorpay key must still walk end to end, or the whole
      // flow is untestable and undemonstrable without a merchant account.
      final reference = await _repository(
        const SimulatedPaymentGateway(),
        api: const FakePaymentRemoteDataSource(),
      ).pay(summary: _summary, method: PaymentMethod.card);

      expect(reference, isNotEmpty);
    });

    test('it orders nothing, because there is nothing to order against', () {
      // The simulated path must not reach the order route: a stand-in gateway
      // paired with a real order would create a Razorpay order that nothing
      // ever pays, once per tap.
      final api = _RecordingApi();

      return _repository(
        const SimulatedPaymentGateway(),
        api: api,
      ).pay(summary: _summary, method: PaymentMethod.card).then((_) {
        expect(api.orderCount, 0);
        expect(api.confirmCount, 0);
      });
    });

    test('it does not claim to be live', () {
      expect(const SimulatedPaymentGateway().isLive, isFalse);
    });
  });

  group('a live build', () {
    tearDown(sl.reset);

    test('never silently simulates a payment', () {
      // The bug this exists to prevent, and it was in the wiring rather than in
      // any of the code above: a live build with no key resolved the stand-in,
      // the stand-in answers "paid" after no delay at all, and the flow believed
      // it. The slot was booked, the confirmation written and the patient's
      // phone buzzed to say their consultation was booked — no sheet, no money,
      // and nothing to refund because nothing was ever charged.
      //
      // On screen it looked like Razorpay failing to open. It was the app
      // giving consultations away.
      sl.reset();
      configureDependencies(backend: AppBackend.live);

      expect(sl<PaymentGateway>(), isNot(isA<SimulatedPaymentGateway>()));
    });

    test('refuses outright when no gateway is configured', () async {
      // "I could not take the payment" is the only honest answer, and a refusal
      // the patient can read beats a booking nobody paid for.
      await expectLater(
        const UnconfiguredPaymentGateway().collect(
          amountInRupees: 850,
          description: 'Video Consultation with Dr. Amit Verma',
        ),
        throwsA(isA<Failure>()),
      );
    });

    test('the refusal does not read as a cancelled sheet', () {
      // A cancelled payment is the patient changing their mind and is not worth
      // a red screen. This is the platform being broken, and must not be
      // reported as though they had done something.
      expect(
        const UnconfiguredPaymentGateway().isLive,
        isTrue,
        reason:
            'false would send the repository down the simulated branch, '
            'which charges nothing and hands back a reference anyway',
      );
    });
  });
}
