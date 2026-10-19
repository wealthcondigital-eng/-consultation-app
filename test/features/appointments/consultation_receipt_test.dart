import 'package:consultation_app/features/appointments/domain/entities/appointment.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _appointment({
  int? fee = 900,
  String? paymentId = 'pay_NqXsAmpLe0192',
  String? registration = 'KA-2009-11238',
  AppointmentStatus status = AppointmentStatus.completed,
}) {
  return Appointment(
    id: 'appointment-done',
    counterpartName: 'Dr. Vinay Kumar',
    counterpartSubtitle: 'Cardiologist',
    mode: ConsultationMode.audio,
    status: status,
    requestedAt: DateTime(2026, 9, 21, 10),
    startedAt: DateTime(2026, 9, 21, 10, 1),
    endedAt: DateTime(2026, 9, 21, 10, 13),
    durationSeconds: 720,
    fee: fee,
    paymentId: paymentId,
    paidAt: DateTime(2026, 9, 21, 9, 59),
    counterpartRegistrationNumber: registration,
  );
}

void main() {
  group('hasReceipt', () {
    test('is true once money changed hands', () {
      expect(_appointment().hasReceipt, isTrue);
    });

    test('is false for a consultation that was never charged', () {
      expect(_appointment(fee: null).hasReceipt, isFalse);
      expect(_appointment(fee: 0).hasReceipt, isFalse);
    });

    test('survives a cancellation, because a refund still has a receipt', () {
      expect(
        _appointment(status: AppointmentStatus.cancelled).hasReceipt,
        isTrue,
      );
    });

    test('does not depend on the payment id having arrived', () {
      // An older row predates the API returning one. It still cost money and
      // still has a receipt; the transaction line simply reads as unavailable.
      expect(_appointment(paymentId: null).hasReceipt, isTrue);
    });
  });

  group('the receipt fields', () {
    test('carry the registration number the NMC guidelines ask for', () {
      expect(_appointment().counterpartRegistrationNumber, 'KA-2009-11238');
    });

    test('are all optional, so a consultation that never connected builds', () {
      final bare = Appointment(
        id: 'appointment-expired',
        counterpartName: 'Finding a doctor',
        mode: ConsultationMode.video,
        status: AppointmentStatus.expired,
        requestedAt: DateTime(2026, 9, 17),
      );

      expect(bare.paymentId, isNull);
      expect(bare.paidAt, isNull);
      expect(bare.counterpartRegistrationNumber, isNull);
      expect(bare.hasReceipt, isFalse);
    });
  });

  group('payment status', () {
    test('reads the API words, folding captured into paid', () {
      expect(PaymentStatus.from('paid'), PaymentStatus.paid);
      expect(PaymentStatus.from('captured'), PaymentStatus.paid);
      expect(PaymentStatus.from('failed'), PaymentStatus.failed);
      expect(PaymentStatus.from('refunded'), PaymentStatus.refunded);
      expect(PaymentStatus.from('created'), PaymentStatus.pending);
      expect(PaymentStatus.from(null), isNull);
    });

    test('is inferred as paid from a reference on an older row', () {
      expect(_appointment().effectivePaymentStatus, PaymentStatus.paid);
    });

    test('is unknown on a charged row with no reference', () {
      final row = Appointment(
        id: 'x',
        counterpartName: 'Dr. A',
        mode: ConsultationMode.video,
        status: AppointmentStatus.completed,
        requestedAt: DateTime(2026, 9, 21),
        fee: 500,
      );
      expect(row.effectivePaymentStatus, isNull);
    });

    test('the API status wins over the inference', () {
      final row = Appointment(
        id: 'x',
        counterpartName: 'Dr. A',
        mode: ConsultationMode.video,
        status: AppointmentStatus.cancelled,
        requestedAt: DateTime(2026, 9, 21),
        fee: 500,
        paymentId: 'pay_1',
        paymentStatus: PaymentStatus.refunded,
        refundedAmount: 500,
      );
      expect(row.effectivePaymentStatus, PaymentStatus.refunded);
    });

    test('the total includes the platform fee when the API sends it', () {
      final row = Appointment(
        id: 'x',
        counterpartName: 'Dr. A',
        mode: ConsultationMode.video,
        status: AppointmentStatus.completed,
        requestedAt: DateTime(2026, 9, 21),
        fee: 500,
        amountPaid: 520,
      );
      expect(row.totalLabel, '₹520');
      expect(_appointment().totalLabel, '₹900');
    });
  });
}
