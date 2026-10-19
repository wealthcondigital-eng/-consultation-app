import '../../../../core/error/failure.dart';

/// Why a booking did not go through, in the terms that decide what the patient
/// should do next.
///
/// Not a list of error codes. Each value is a different answer to the two
/// questions a patient actually has after a failed payment — *has money left my
/// account?* and *what do I do now?* — and those two answers are what the
/// outcome screen is built from. Two failures with the same answers are the
/// same value here, however differently they came about.
enum PaymentFailureReason {
  /// They closed Razorpay's sheet. Nothing was charged, nothing was booked,
  /// and trying again is safe.
  cancelled(isCharged: false, canRetry: true),

  /// The bank, the card or the UPI app said no, or checkout could not start.
  /// Nothing was charged. Trying again — perhaps another way — is safe.
  declined(isCharged: false, canRetry: true),

  /// Razorpay may have taken the money, but the server could not confirm it.
  ///
  /// **The one reason that must never offer Try again.** A second attempt here
  /// is how a patient gets charged twice for one consultation. The honest
  /// instruction is to wait: a captured payment is confirmed by the webhook
  /// within minutes, and an uncaptured one is released by the bank on its own.
  unconfirmed(isCharged: true, canRetry: false),

  /// The slot went to somebody else between choosing it and paying. Checked
  /// before any money moves, so nothing was charged.
  slotUnavailable(isCharged: false, canRetry: false),

  /// Paid, and then no doctor answered the instant consultation. The server
  /// refunds this automatically.
  noDoctor(isCharged: true, canRetry: false),

  /// Paid, and then the patient called the search off before a doctor answered.
  /// Refunded the same way, because nothing was delivered.
  withdrawn(isCharged: true, canRetry: false);

  const PaymentFailureReason({required this.isCharged, required this.canRetry});

  /// True when money did, or may have, left the account. Decides whether the
  /// screen talks about a refund at all — telling someone who closed the sheet
  /// that "your refund is on its way" is alarming and wrong.
  final bool isCharged;

  /// True when paying again is safe *and* useful.
  final bool canRetry;

  /// Which reason a [Failure] from the payment flow amounts to.
  ///
  /// Read off the code where there is one and only where there is one. Prose
  /// changes and codes do not; a mapping built on sentences breaks the first
  /// time one is reworded, and the reason it breaks into here is `declined` —
  /// which offers Try again. For `unconfirmed` that would be the double charge
  /// this enum exists to prevent, so that one is matched on its code alone.
  static PaymentFailureReason from(Failure failure) {
    return switch (failure.code) {
      'payment_cancelled' => PaymentFailureReason.cancelled,
      'payment_unconfirmed' => PaymentFailureReason.unconfirmed,
      'slot_taken' ||
      'slot_unavailable' => PaymentFailureReason.slotUnavailable,
      _ => PaymentFailureReason.declined,
    };
  }
}
