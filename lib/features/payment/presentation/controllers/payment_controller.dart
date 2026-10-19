import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/l10n/tr.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../consultation/domain/entities/live_consultation.dart';
import '../../../consultation/domain/usecases/start_instant_consultation.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../domain/entities/fee_breakdown.dart';
import '../../domain/entities/payment_failure.dart';
import '../../domain/entities/payment_method.dart';
import '../../domain/entities/payment_summary.dart';
import '../../domain/entities/upi_id.dart';
import '../../domain/usecases/get_payment_summary.dart';
import '../../domain/usecases/pay_for_consultation.dart';
import '../../domain/usecases/verify_upi_id.dart';

enum PaymentAction { none, loading, verifying, paying }

/// The one switch for taking payments.
///
/// **False: payments are on** (Razorpay, restored 2026-10-13). Set it to true
/// to confirm bookings without payment again — every place it changes is
/// marked `paymentsPaused` — and set `PAYMENTS_ENABLED` to match on the API.
const bool paymentsPaused = false;

/// Presentation state for the payment screen.
class PaymentController extends ChangeNotifier {
  PaymentController(
    this._getSummary,
    this._verifyUpiId,
    this._pay,
    this._consultations, {
    this.gatewayCollectsMethod = false,
  });

  /// True when the gateway asks for the payment method inside its own sheet.
  ///
  /// Injected from the gateway that will actually run, rather than read off a
  /// compile-time constant. The two differ exactly where it matters: a build
  /// with a key configured still runs the simulated gateway under test and on
  /// the fake backend, and a screen that hid its picker on the strength of the
  /// constant hid it there too — leaving no picker, no sheet and nothing to tap.
  final bool gatewayCollectsMethod;

  final GetPaymentSummary _getSummary;

  final VerifyUpiId _verifyUpiId;
  final PayForConsultation _pay;

  /// Files the appointment once it is paid for.
  ///
  /// Here rather than on the confirmation screen, because the confirmation is
  /// where the old flow **stopped**: it said "Appointment scheduled" and wrote
  /// nothing anywhere. The slot existed only as a sentence the patient had
  /// read — no row on the doctor's dashboard, nothing on either appointment
  /// list, and nothing to join when the time came.
  final StartInstantConsultation _consultations;

  /// The booking, once it has been filed. Null on an instant consultation,
  /// which has nothing to book.
  LiveConsultation? _booking;
  LiveConsultation? get booking => _booking;

  PaymentSummary? _summary;
  PaymentSummary? get summary => _summary;

  /// Why the last attempt did not go through, or null when it did — or when
  /// there has not been one. What the outcome screen is built from.
  PaymentFailureReason? _failureReason;
  PaymentFailureReason? get failureReason => _failureReason;

  /// UPI when the app is collecting the payment itself, and a method needing
  /// no inline detail when Razorpay is — because with Razorpay there is no
  /// picker on screen, so a default that demands a UPI ID is a default nobody
  /// can satisfy.
  late PaymentMethod _method = gatewayCollectsMethod
      ? PaymentMethod.card
      : PaymentMethod.upi;
  PaymentMethod get method => _method;

  UpiId _upiId = const UpiId.empty();
  UpiId get upiId => _upiId;

  /// The account holder returned by verification, once it has succeeded.
  String? _verifiedAccountName;
  String? get verifiedAccountName => _verifiedAccountName;

  bool get isUpiVerified => _verifiedAccountName != null;

  PaymentAction _action = PaymentAction.none;
  PaymentAction get action => _action;

  bool get isLoading => _action == PaymentAction.loading;
  bool get isVerifying => _action == PaymentAction.verifying;
  bool get isPaying => _action == PaymentAction.paying;
  bool get isBusy => _action != PaymentAction.none;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _transactionId;
  String? get transactionId => _transactionId;

  /// Verification is offered only once the address could plausibly exist.
  bool get canVerifyUpi => _upiId.isWellFormed && !isBusy;

  /// UPI is the only method that needs detail collected before paying; the
  /// others hand off to the gateway's own sheet.
  bool get canPay {
    if (_summary == null || isBusy) return false;

    // paymentsPaused: no method to choose, so nothing can hold the button shut.
    if (paymentsPaused) return true;

    // Belt and braces alongside the default above. Whatever the method reads
    // as, it is not what Razorpay will use, so it must not be able to hold the
    // button shut.
    if (gatewayCollectsMethod) return true;

    if (_method.needsUpiId) return _upiId.isWellFormed;
    return true;
  }

  String get payLabel {
    final total = _summary?.fees.formattedTotal;
    return total == null ? tr('Pay') : tr('Pay {amount}', {'amount': total});
  }

  Future<void> load(Doctor doctor, ConsultationMode mode) async {
    if (isBusy) return;

    _action = PaymentAction.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // The server prices the consultation — the app displays the answer, it
      // does not compute one. While payments are paused nothing is charged,
      // so the doctor's own listed fee is shown instead: the quote refuses
      // outright for a doctor with no fee set, which would block a booking
      // that costs nothing.
      _summary = paymentsPaused
          ? PaymentSummary(
              doctor: doctor,
              mode: mode,
              fees: FeeBreakdown(
                consultationFee: doctor.feeFor(mode),
                platformFee: 0,
              ),
            )
          : await _getSummary(doctor: doctor, mode: mode);
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _action = PaymentAction.none;
      notifyListeners();
    }
  }

  void changeMethod(PaymentMethod value) {
    if (value == _method) return;
    _method = value;
    _errorMessage = null;
    notifyListeners();
  }

  void changeUpiId(String value) {
    if (value == _upiId.value) return;

    _upiId = UpiId(value);
    // Editing invalidates any earlier verification.
    _verifiedAccountName = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Returns true when the address was confirmed.
  Future<bool> verifyUpi() async {
    if (!canVerifyUpi) return false;

    _action = PaymentAction.verifying;
    _errorMessage = null;
    notifyListeners();

    try {
      _verifiedAccountName = await _verifyUpiId(_upiId);
      return true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      return false;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      return false;
    } finally {
      _action = PaymentAction.none;
      notifyListeners();
    }
  }

  /// Returns true when the payment went through — and, for a booking, when the
  /// appointment was actually filed.
  ///
  /// [scheduledAt] books the slot. The two steps are not independent: a patient
  /// who has paid and holds no appointment is worse off than one who was told
  /// the slot had gone, so a booking that fails is reported as a failure of the
  /// whole thing rather than confirmed on the strength of the payment alone.
  ///
  /// **Booking first is deliberate**, and it is the reverse of what this used
  /// to do. Charging first meant a booking call that failed left the patient
  /// paid-up with no appointment; holding the slot first means a booking that
  /// cannot be made costs nothing. The risk it trades into — a diary holding an
  /// appointment nobody paid for — is closed by releasing the slot whenever the
  /// payment does not complete.
  Future<bool> pay({
    DateTime? scheduledAt,
    String? concern,
    bool isAnonymous = false,
    String? alias,

    /// How the slot reads, e.g. `Mon, 18 Aug at 10:30 AM`. The screen already
    /// has it; formatting it twice risks the notification and the confirmation
    /// screen disagreeing about the same appointment.
    String? scheduledFor,
  }) async {
    final summary = _summary;
    if (summary == null || !canPay) return false;

    // A previous attempt may have left one held — a patient who cancelled the
    // sheet and tapped Pay again should not end up holding two.
    await _releaseHeldSlot();

    _action = PaymentAction.paying;
    _errorMessage = null;
    _failureReason = null;
    notifyListeners();

    try {
      // **The slot first, the money second.** This used to run the other way
      // round, and the cost of that was the worst outcome the flow has: the
      // patient paid, the booking call then failed, and they were left charged
      // with no appointment and an error quoting an HTTP route at them. Holding
      // the slot first means a booking that cannot be made costs nothing —
      // which is exactly what happens today, because the server has no
      // scheduling endpoint yet.
      if (scheduledAt != null) {
        _booking = await _consultations.schedule(
          doctorId: summary.doctor.id,
          mode: summary.mode,
          scheduledAt: scheduledAt,
          concern: concern,
          isAnonymous: isAnonymous,
          alias: alias,
        );
      }

      // While payments are paused the booking is confirmed without taking
      // any money — the server confirms it itself (PAYMENTS_ENABLED off).
      if (paymentsPaused) {
        _transactionId = null;
      } else {
        try {
          _transactionId = await _pay(
            summary: summary,
            method: _method,
            // Razorpay collects the method itself, so nothing chosen here is
            // sent.
            upiId: gatewayCollectsMethod && _method.needsUpiId
                ? null
                : (_method.needsUpiId ? _upiId : null),
            // The slot held a moment ago, so the server can mark it paid
            // rather than leaving a booking indistinguishable from an
            // abandoned hold. Null on an instant consultation, which has no
            // row until a doctor answers — that one is linked by the order's
            // notes instead.
            consultationId: _booking?.id,
          );
        } catch (_) {
          // Paying failed or was cancelled, so the slot has to go back.
          // Holding it would take a time out of the doctor's day that nobody
          // paid for and no patient is coming to.
          await _releaseHeldSlot();
          rethrow;
        }
      }

      // **The confirmation is not written here.** The server files it, and
      // both reminders with it, the moment the payment verifies — see
      // `PaymentsService.markConsultationPaid`. Writing it here as well put two
      // "Consultation booked" notifications in the tray for one appointment,
      // and only one of them could reach the doctor's handset.
      //
      // It has to be the server's job rather than this one's for a reason that
      // outlives the duplicate: a patient whose app is killed on the Razorpay
      // sheet still paid, and the webhook still confirms it. A confirmation
      // written from here would simply never be written for them.
      return true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      _failureReason = PaymentFailureReason.from(failure);
      return false;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      _failureReason = PaymentFailureReason.declined;
      return false;
    } finally {
      _action = PaymentAction.none;
      notifyListeners();
    }
  }

  /// Gives back a slot that was held for a payment that did not happen.
  ///
  /// Never throws. The patient is already being told their payment failed, and
  /// a second error about the cleanup would say nothing they can act on — the
  /// booking is unpaid either way, and the server expires an unconfirmed hold
  /// on its own.
  Future<void> _releaseHeldSlot() async {
    final held = _booking;
    if (held == null) return;

    _booking = null;
    try {
      await _consultations.cancel(held.id);
    } catch (_) {
      // Nothing to say and nothing to retry.
    }
  }
}
