import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:consultation_app/features/payment/data/datasources/payment_remote_data_source.dart';
import 'package:consultation_app/features/payment/data/datasources/payment_gateway.dart';
import 'package:consultation_app/features/payment/data/repositories/payment_repository_impl.dart';
import 'package:consultation_app/features/payment/domain/entities/fee_breakdown.dart';
import 'package:consultation_app/features/payment/domain/entities/payment_method.dart';
import 'package:consultation_app/features/payment/domain/entities/upi_id.dart';
import 'package:consultation_app/features/payment/domain/usecases/get_payment_summary.dart';
import 'package:consultation_app/features/payment/domain/usecases/pay_for_consultation.dart';
import 'package:consultation_app/features/payment/domain/usecases/verify_upi_id.dart';
import 'package:flutter_test/flutter_test.dart';

const _doctor = Doctor(
  id: 'amit-verma',
  name: 'Dr. Amit Verma',
  speciality: 'Senior Cardiologist',
  yearsOfExperience: 15,
  rating: 4.9,
  consultationFee: 800,
);

final _repository = PaymentRepositoryImpl(
  const FakePaymentRemoteDataSource(),
  // No real checkout in a test: the stand-in is what a build with no Razorpay
  // key uses too, so this is the same path a keyless build walks.
  const SimulatedPaymentGateway(),
);

void main() {
  group('FeeBreakdown', () {
    const fees = FeeBreakdown(consultationFee: 800, platformFee: 50);

    test('totals its lines', () {
      expect(fees.total, 850);
    });

    test('formats every figure with the currency symbol', () {
      expect(fees.formattedConsultationFee, '₹800');
      expect(fees.formattedPlatformFee, '₹50');
      expect(fees.formattedTotal, '₹850');
    });
  });

  group('UpiId', () {
    test('accepts a handle@bank address', () {
      expect(const UpiId('amit.verma@okaxis').isWellFormed, isTrue);
      expect(const UpiId('amit-verma@ybl').isWellFormed, isTrue);
    });

    test('rejects anything else', () {
      expect(const UpiId.empty().isWellFormed, isFalse);
      expect(const UpiId('amit.verma').isWellFormed, isFalse);
      expect(const UpiId('@okaxis').isWellFormed, isFalse);
      expect(const UpiId('a@b').isWellFormed, isFalse);
    });
  });

  group('GetPaymentSummary', () {
    test("combines the doctor's fee with the platform fee", () async {
      final summary = await GetPaymentSummary(_repository)(doctor: _doctor);

      expect(summary.doctor.name, 'Dr. Amit Verma');
      expect(summary.fees.consultationFee, 800);
      expect(summary.fees.platformFee, 50);
      expect(summary.fees.formattedTotal, '₹850');
    });
  });

  group('VerifyUpiId', () {
    test('returns the account holder for a known address', () async {
      final name = await VerifyUpiId(_repository)(
        const UpiId('amit.verma@okaxis'),
      );

      expect(name, 'Amit Verma');
    });

    test('rejects a malformed address without a round trip', () {
      expect(
        () => VerifyUpiId(_repository)(const UpiId('nope')),
        throwsA(isA<Failure>()),
      );
    });

    test('surfaces an unknown address', () {
      expect(
        () => VerifyUpiId(_repository)(
          const UpiId('someone${FakePaymentRemoteDataSource.unknownHandle}'),
        ),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('PayForConsultation', () {
    test('refuses UPI without a valid ID, whatever the UI allowed', () async {
      final summary = await GetPaymentSummary(_repository)(doctor: _doctor);

      expect(
        () => PayForConsultation(_repository)(
          summary: summary,
          method: PaymentMethod.upi,
          upiId: const UpiId('nope'),
        ),
        throwsA(isA<Failure>()),
      );
    });

    test('does not require a UPI ID for other methods', () async {
      final summary = await GetPaymentSummary(_repository)(doctor: _doctor);

      expect(
        await PayForConsultation(_repository)(
          summary: summary,
          method: PaymentMethod.card,
        ),
        isNotEmpty,
      );
    });

    test('returns a transaction reference on success', () async {
      final summary = await GetPaymentSummary(_repository)(doctor: _doctor);

      final reference = await PayForConsultation(_repository)(
        summary: summary,
        method: PaymentMethod.upi,
        upiId: const UpiId('amit.verma@okaxis'),
      );

      expect(reference, contains('850'));
    });
  });
}
