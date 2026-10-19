import 'package:consultation_app/core/error/failure.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/consultation/domain/entities/live_consultation.dart';
import 'package:consultation_app/features/consultation/domain/repositories/consultation_session_repository.dart';
import 'package:consultation_app/features/consultation/domain/usecases/start_instant_consultation.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:consultation_app/features/payment/domain/entities/fee_breakdown.dart';
import 'package:consultation_app/features/payment/domain/entities/payment_failure.dart';
import 'package:consultation_app/features/payment/domain/entities/payment_method.dart';
import 'package:consultation_app/features/payment/domain/entities/payment_summary.dart';
import 'package:consultation_app/features/payment/domain/entities/upi_id.dart';
import 'package:consultation_app/features/payment/domain/repositories/payment_repository.dart';
import 'package:consultation_app/features/payment/domain/usecases/get_payment_summary.dart';
import 'package:consultation_app/features/payment/domain/usecases/pay_for_consultation.dart';
import 'package:consultation_app/features/payment/domain/usecases/verify_upi_id.dart';
import 'package:consultation_app/features/payment/presentation/controllers/payment_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _doctor = Doctor(
  id: 'doctor-1',
  name: 'Dr. Anita Desai',
  speciality: 'Dermatologist',
  yearsOfExperience: 9,
  rating: 4.7,
  consultationFee: 750,
);

class _StubPaymentRepository implements PaymentRepository {
  _StubPaymentRepository({this.payFailure});

  /// What the gateway does. A cancelled sheet is the case that matters: the
  /// slot was already held by then and has to go back.
  final Failure? payFailure;

  var charged = 0;
  String? paidForConsultation;

  @override
  bool get gatewayCollectsMethod => false;

  @override
  Future<PaymentSummary> fetchSummary({
    required Doctor doctor,
    required ConsultationMode mode,
  }) async {
    return PaymentSummary(
      doctor: doctor,
      mode: mode,
      fees: const FeeBreakdown(consultationFee: 750, platformFee: 0),
    );
  }

  @override
  Future<String> pay({
    required PaymentSummary summary,
    required PaymentMethod method,
    UpiId? upiId,
    String? consultationId,
  }) async {
    charged++;
    // The booking the payment settles. Recorded so a test can assert the held
    // slot is the one the server is told to mark paid.
    paidForConsultation = consultationId;
    if (payFailure case final failure?) throw failure;
    return 'txn-1';
  }

  @override
  Future<String> verifyUpiId(UpiId upiId) async => 'Anita Desai';
}

/// Records the booking, so a test can assert what reached the API.
class _RecordingConsultations implements ConsultationSessionRepository {
  _RecordingConsultations({this.failure});

  final Failure? failure;

  String? doctorId;
  DateTime? scheduledAt;
  String? concern;
  bool? isAnonymous;
  String? alias;
  int calls = 0;

  @override
  Future<LiveConsultation> schedule({
    required String doctorId,
    required ConsultationMode mode,
    required DateTime scheduledAt,
    String? concern,
    bool isAnonymous = false,
    String? alias,
  }) async {
    calls++;
    this.doctorId = doctorId;
    this.scheduledAt = scheduledAt;
    this.concern = concern;
    this.isAnonymous = isAnonymous;
    this.alias = alias;

    if (failure case final failure?) throw failure;

    return LiveConsultation(
      id: 'consultation-1',
      status: LiveConsultationStatus.scheduled,
      mode: mode,
      channelId: 'consult-room',
      peerId: 'patient-consultation-1',
      isCaller: true,
      patientName: alias ?? 'Rahul Sharma',
      isAnonymous: isAnonymous,
      scheduledAt: scheduledAt,
      concern: concern,
    );
  }

  // --- Not used by the booking path ----------------------------------------

  @override
  Future<LiveConsultation> requestInstant({
    required ConsultationMode mode,
    String? speciality,
    bool isAnonymous = false,
    String? alias,
    String? concern,
  }) => throw UnimplementedError();

  @override
  Stream<LiveConsultation> watch(String id) => const Stream.empty();

  @override
  Stream<LiveConsultation?> watchIncoming() => const Stream.empty();

  @override
  Future<LiveConsultation> accept(String id) => throw UnimplementedError();

  /// Ids the controller gave back after a payment that did not complete.
  final cancelled = <String>[];

  @override
  Future<LiveConsultation> cancel(String id) async {
    cancelled.add(id);
    return LiveConsultation(
      id: id,
      status: LiveConsultationStatus.cancelled,
      mode: ConsultationMode.video,
      channelId: 'consult-room',
      peerId: 'patient-',
      isCaller: true,
      patientName: 'Rahul Sharma',
    );
  }

  @override
  Future<LiveConsultation> decline(String id) => throw UnimplementedError();

  @override
  Future<LiveConsultation> end(String id) => throw UnimplementedError();

  @override
  Future<LiveConsultation> join(String id) => throw UnimplementedError();

  @override
  Future<void> rate(
    String id, {
    required int rating,
    String? feedback,
    int? callQuality,
    List<String> tags = const [],
  }) => throw UnimplementedError();
}

Future<PaymentController> _loaded(
  _RecordingConsultations consultations, {
  _StubPaymentRepository? payments,
}) async {
  final repository = payments ?? _StubPaymentRepository();

  final controller = PaymentController(
    GetPaymentSummary(repository),
    VerifyUpiId(repository),
    PayForConsultation(repository),
    StartInstantConsultation(consultations),
    // No announcer. The confirmation and its reminders are the server's to
    // write, and it writes them when the payment verifies rather than when the
    // slot is held — see `PaymentsService.markConsultationPaid`. Raising them
    // here as well put two "Consultation booked" notifications in the tray for
    // one appointment, the earlier of which arrived before anybody had paid.
  );

  await controller.load(_doctor, ConsultationMode.video);
  controller.changeMethod(PaymentMethod.card);

  return controller;
}

void main() {
  group('paying for a booking', () {
    final slot = DateTime(2026, 9, 17, 15, 30);

    test('files the appointment, so it reaches the doctor', () async {
      // The bug this covers: the booking flow ended at a screen that said
      // "Appointment scheduled" and wrote nothing anywhere. The slot existed
      // only as a sentence the patient had read — no row on the doctor's
      // dashboard, nothing on either appointment list, and nothing to join
      // when the time came.
      final consultations = _RecordingConsultations();
      final controller = await _loaded(consultations);
      addTearDown(controller.dispose);

      final paid = await controller.pay(scheduledAt: slot);

      expect(paid, isTrue);
      expect(consultations.calls, 1);
      expect(consultations.doctorId, 'doctor-1');
      expect(consultations.scheduledAt, slot);
      expect(controller.booking?.scheduledAt, slot);
      expect(controller.booking?.status, LiveConsultationStatus.scheduled);
    });

    test('carries the alias and the concern of an anonymous booking', () async {
      final consultations = _RecordingConsultations();
      final controller = await _loaded(consultations);
      addTearDown(controller.dispose);

      await controller.pay(
        scheduledAt: slot,
        concern: 'Trouble sleeping for a month.',
        isAnonymous: true,
        alias: 'Patient Hawk',
      );

      expect(consultations.isAnonymous, isTrue);
      expect(consultations.alias, 'Patient Hawk');
      expect(consultations.concern, 'Trouble sleeping for a month.');
    });

    test('an instant consultation books nothing', () async {
      // There is no slot to hold: the patient is matched with whoever is free,
      // and the consultation is filed by matching.
      final consultations = _RecordingConsultations();
      final controller = await _loaded(consultations);
      addTearDown(controller.dispose);

      final paid = await controller.pay();

      expect(paid, isTrue);
      expect(consultations.calls, 0);
      expect(controller.booking, isNull);
    });

    test('a slot that was taken fails the whole payment', () async {
      // Reported as a failure of the thing as a whole rather than confirmed on
      // the strength of the payment alone: a patient who has paid and holds no
      // appointment is worse off than one who was told the slot had gone.
      final consultations = _RecordingConsultations(
        failure: const Failure('That slot has just been booked.'),
      );
      final controller = await _loaded(consultations);
      addTearDown(controller.dispose);

      final paid = await controller.pay(scheduledAt: slot);

      expect(paid, isFalse);
      expect(controller.errorMessage, 'That slot has just been booked.');
      expect(controller.booking, isNull);
    });

    test('a booking that cannot be made costs nothing', () async {
      // The order this guards. Paying used to run first, so a booking call that
      // failed afterwards left the patient charged with no appointment and an
      // error quoting an HTTP route at them — which is exactly what the missing
      // scheduling endpoint produced on a real device.
      final payments = _StubPaymentRepository();
      final consultations = _RecordingConsultations(
        failure: const Failure('Booking a slot is not available yet.'),
      );
      final controller = await _loaded(consultations, payments: payments);
      addTearDown(controller.dispose);

      final paid = await controller.pay(scheduledAt: slot);

      expect(paid, isFalse);
      expect(payments.charged, 0, reason: 'no money moves for a dead slot');
      expect(controller.errorMessage, contains('not available yet'));
    });

    test('a payment that fails gives the slot back', () async {
      // Otherwise a cancelled sheet takes a time out of the doctor's day that
      // nobody paid for and no patient is coming to.
      final consultations = _RecordingConsultations();
      final controller = await _loaded(
        consultations,
        payments: _StubPaymentRepository(
          payFailure: const Failure('Payment was cancelled.'),
        ),
      );
      addTearDown(controller.dispose);

      final paid = await controller.pay(scheduledAt: slot);

      expect(paid, isFalse);
      expect(consultations.cancelled, ['consultation-1']);
      expect(controller.booking, isNull);
    });

    test('a successful booking is not cancelled on the way out', () async {
      final consultations = _RecordingConsultations();
      final controller = await _loaded(consultations);
      addTearDown(controller.dispose);

      await controller.pay(scheduledAt: slot);

      expect(consultations.cancelled, isEmpty);
    });
  });

  group('a booking that does not go through stops there', () {
    final slot = DateTime(2026, 9, 17, 15, 30);

    test('a cancelled sheet gives the slot back and books nothing', () async {
      final consultations = _RecordingConsultations();
      final payments = _StubPaymentRepository(
        payFailure: const Failure(
          'Payment was cancelled.',
          code: 'payment_cancelled',
        ),
      );
      final controller = await _loaded(consultations, payments: payments);

      final ok = await controller.pay(scheduledAt: slot);

      expect(ok, isFalse);
      expect(controller.failureReason, PaymentFailureReason.cancelled);
      // Held before checkout opened, so it has to go back — or a time nobody
      // paid for comes out of the doctor's day.
      expect(consultations.cancelled, ['consultation-1']);
      expect(controller.booking, isNull);
      expect(controller.transactionId, isNull);
    });

    test('a slot taken first is refused before any money moves', () async {
      final consultations = _RecordingConsultations(
        failure: const Failure(
          'That slot has just been booked.',
          code: 'slot_taken',
        ),
      );
      final payments = _StubPaymentRepository();
      final controller = await _loaded(consultations, payments: payments);

      final ok = await controller.pay(scheduledAt: slot);

      expect(ok, isFalse);
      expect(controller.failureReason, PaymentFailureReason.slotUnavailable);
      // The slot is checked first, which is the whole point of the ordering:
      // a booking that cannot be made costs nothing.
      expect(payments.charged, 0);
    });

    test('an unconfirmed payment is reported as one', () async {
      final consultations = _RecordingConsultations();
      final payments = _StubPaymentRepository(
        payFailure: const Failure(
          'We could not confirm your payment.',
          code: 'payment_unconfirmed',
        ),
      );
      final controller = await _loaded(consultations, payments: payments);

      await controller.pay(scheduledAt: slot);

      expect(controller.failureReason, PaymentFailureReason.unconfirmed);
      expect(controller.failureReason!.canRetry, isFalse);
    });

    test('a fresh attempt clears the last failure', () async {
      final consultations = _RecordingConsultations();
      final payments = _StubPaymentRepository(
        payFailure: const Failure('The bank declined it.'),
      );
      final controller = await _loaded(consultations, payments: payments);

      await controller.pay(scheduledAt: slot);
      expect(controller.failureReason, PaymentFailureReason.declined);

      // Succeeds this time. The outcome screen must not reopen on a stale
      // reason from the attempt before.
      final retry = await _loaded(consultations);
      final ok = await retry.pay(scheduledAt: slot);

      expect(ok, isTrue);
      expect(retry.failureReason, isNull);
    });
  });
}
