import '../../../../core/error/failure.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/fee_breakdown.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/entities/payment_summary.dart';
import '../../domain/entities/upi_id.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_gateway.dart';
import '../datasources/payment_remote_data_source.dart';

class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl(this._remoteDataSource, this._gateway);

  final PaymentRemoteDataSource _remoteDataSource;

  /// Where the money actually changes hands. The data source still records
  /// the charge against the consultation; this is what opens the sheet.
  final PaymentGateway _gateway;

  @override
  bool get gatewayCollectsMethod => _gateway.collectsMethodItself;

  @override
  Future<PaymentSummary> fetchSummary({
    required Doctor doctor,
    required ConsultationMode mode,
  }) async {
    try {
      // Priced by the server, both halves of it. The app used to ask only for
      // the platform fee and add it to a figure off the doctor listing, so the
      // total shown and the total charged were computed in two places with
      // nothing keeping them equal.
      final quote = await _remoteDataSource.fetchQuote(
        doctorId: doctor.id,
        mode: mode.name,
      );

      return PaymentSummary(
        doctor: doctor,
        mode: mode,
        fees: FeeBreakdown(
          // The doctor entity's own figure stands in only where the server did
          // not price it — the simulated path. Doctors may price audio
          // differently from video, which `feeFor` already knows.
          consultationFee: quote.consultationFee ?? doctor.feeFor(mode),
          platformFee: quote.platformFee,
          currencySymbol: doctor.currencySymbol,
        ),
        // The server's answer, because the server holds the key: a debug
        // build talking to production is live, and a release build talking
        // to a test server is not.
        isTestMode: quote.isTestMode,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  @override
  Future<String> verifyUpiId(UpiId upiId) async {
    try {
      return await _remoteDataSource.verifyUpiId(upiId.value.trim());
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure.unexpected();
    }
  }

  @override
  Future<String> pay({
    required PaymentSummary summary,
    required PaymentMethod method,
    UpiId? upiId,
    String? consultationId,
  }) async {
    try {
      if (!_gateway.isLive) {
        // No gateway configured. The simulated path still opens its stand-in
        // and records a charge, so the booking flow stays walkable end to end
        // in a build with no key and under test.
        await _gateway.collect(
          amountInRupees: summary.fees.total,
          description: '${summary.mode.label} with ${summary.doctor.name}',
        );

        return _remoteDataSource.charge(
          amount: summary.fees.total,
          method: method.name,
        );
      }

      // **The order first.** This is what makes the amount unforgeable: the
      // server prices the consultation from the doctor's own record and creates
      // the order, and Razorpay then charges what the order says regardless of
      // what this handset passes to the SDK. Opening checkout on an amount
      // alone — which is what this did before — bills whatever the app asked
      // for, and a patched build asks for a rupee.
      final order = await _remoteDataSource.createOrder(
        doctorId: summary.doctor.id,
        mode: summary.mode.name,
        consultationId: consultationId,
      );

      final payment = await _gateway.collect(
        // The server's figure, not the screen's. They should agree; where they
        // do not, the one the order was created with is the one being charged,
        // and showing anything else would be a lie about a number the patient
        // is about to see on their statement.
        amountInRupees: order.amountInRupees,
        description: '${summary.mode.label} with ${summary.doctor.name}',
        orderId: order.orderId,
        keyId: order.keyId,
      );

      final signature = payment.signature;
      if (signature == null || payment.orderId == null) {
        // Checkout answered without the two values that make the result
        // checkable. Nothing here can verify them anyway, and a payment that
        // cannot be verified must not be reported as one that was.
        throw const Failure(
          'We could not confirm your payment. If money has left your account '
          'it will be returned automatically.',
          // Coded, not only worded: this is the one failure where paying again
          // risks a double charge, and `PaymentFailureReason.from` matches it
          // on the code alone so rewording the sentence cannot turn it into a
          // failure that offers Try again.
          code: 'payment_unconfirmed',
        );
      }

      // **And the verification last.** Until the server has recomputed the HMAC
      // with the key secret, "payment succeeded" is a sentence this process
      // produced about itself. The consultation goes ahead on the answer to
      // this call, not on the SDK's callback.
      return await _remoteDataSource.confirmPayment(
        orderId: payment.orderId!,
        paymentId: payment.paymentId,
        signature: signature,
        consultationId: consultationId,
      );
    } on Failure {
      rethrow;
    } catch (_) {
      throw const Failure('Payment could not be completed. Please try again.');
    }
  }
}
