import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';

/// Where a consultation ended up.
///
/// The API's statuses, not the screen's, because both sides read the same
/// record — a status the app invents is a status the other end never sees. The
/// three that never connected are kept apart on purpose: a patient looking at
/// why a consultation did not happen needs to know whether they withdrew or
/// nobody answered.
enum AppointmentStatus {
  /// Booked for a time in the future. Nobody is waiting on anybody.
  ///
  /// Distinct from [searching], and its absence was a real bug: an unknown
  /// status fell through to "Finding a doctor", so a confirmed appointment on
  /// Thursday read as a search still running.
  scheduled('Confirmed', AppointmentOutcome.pending),

  searching('Finding a doctor', AppointmentOutcome.pending),
  ringing('Ringing', AppointmentOutcome.pending),
  accepted('Accepted', AppointmentOutcome.pending),
  inProgress('In progress', AppointmentOutcome.pending),
  completed('Completed', AppointmentOutcome.done),
  cancelled('Cancelled', AppointmentOutcome.abandoned),
  expired('No answer', AppointmentOutcome.abandoned);

  const AppointmentStatus(this.label, this.outcome);

  final String label;
  final AppointmentOutcome outcome;

  static AppointmentStatus from(String? value) => switch (value) {
    'scheduled' => AppointmentStatus.scheduled,
    'ringing' => AppointmentStatus.ringing,
    'accepted' => AppointmentStatus.accepted,
    'in_progress' => AppointmentStatus.inProgress,
    'completed' => AppointmentStatus.completed,
    'cancelled' => AppointmentStatus.cancelled,
    'expired' => AppointmentStatus.expired,
    _ => AppointmentStatus.searching,
  };
}

/// What a status amounts to, for a screen deciding how to colour a row.
enum AppointmentOutcome { pending, done, abandoned }

/// Where the money for a consultation stands, as the receipt reports it.
enum PaymentStatus {
  paid('Paid'),
  failed('Payment failed'),
  refunded('Refunded'),
  pending('Payment pending');

  const PaymentStatus(this.label);

  final String label;

  static PaymentStatus? from(Object? value) => switch (value) {
    'paid' || 'captured' => PaymentStatus.paid,
    'failed' => PaymentStatus.failed,
    'refunded' => PaymentStatus.refunded,
    'pending' || 'created' => PaymentStatus.pending,
    _ => null,
  };
}

/// How the consultation was arranged.
///
/// The two are genuinely different things to a patient — one is "I need a
/// doctor now" and the other is "I have an appointment on Thursday" — and the
/// list used to mix them, so a booking three days out sat between two calls
/// that had already happened. They are separated on the list now, which is what
/// this enum is for.
///
/// "Instant", not "Immediate". The app said both, in different places, for the
/// same thing.
enum AppointmentKind {
  instant('Instant', 'Instant Consultation'),
  scheduled('Scheduled', 'Scheduled Consultation');

  const AppointmentKind(this.shortLabel, this.label);

  /// One word, for a chip or a badge.
  final String shortLabel;

  /// The full name, for a section heading.
  final String label;

  /// Reads whatever the API called it.
  ///
  /// Tolerant on purpose: the two API processes have used `kind`, `type` and
  /// the presence of a booked time to mean this, and a row whose kind cannot be
  /// read is an instant consultation — which is what every row was before
  /// scheduling existed, and is the safe default because it is the one with no
  /// appointment time to get wrong.
  static AppointmentKind from(Object? value, {DateTime? scheduledAt}) {
    return switch (value) {
      'scheduled' || 'booking' || 'appointment' => AppointmentKind.scheduled,
      'instant' || 'immediate' => AppointmentKind.instant,
      _ when scheduledAt != null => AppointmentKind.scheduled,
      _ => AppointmentKind.instant,
    };
  }
}

/// Which end of the consultation is asking.
///
/// The two roles read the same rows and each needs the *other* party named, so
/// one entity and one card serve both lists. Two of each would be two mappers
/// and two chances for the doctor's list to end up showing the doctor's own
/// name — which is exactly the bug the call screen had.
enum AppointmentAudience { patient, doctor }

/// Which slice of the history a list is showing.
///
/// A **timeframe**, and only a timeframe. What kind of consultation it was is a
/// separate question asked by [AppointmentKindFilter] — mixing the two axes into
/// one control is how you end up unable to ask for "my scheduled appointments
/// that have not happened yet", which is the single most common thing a patient
/// opens this screen for.
enum AppointmentFilter {
  /// Still ahead: a call in flight, and every booking whose time has not come.
  ///
  /// Labelled "Active" once, which was wrong in both directions — it excluded a
  /// booking on Thursday, and it read as "happening right now" for a request
  /// that was only queued.
  upcoming('Upcoming'),

  past('Past'),

  all('All');

  const AppointmentFilter(this.label);

  final String label;

  /// The query value the API expects.
  String get query => name;
}

/// The other axis: instant, scheduled, or both.
enum AppointmentKindFilter {
  all('All types', null),
  instant('Instant', AppointmentKind.instant),
  scheduled('Scheduled', AppointmentKind.scheduled);

  const AppointmentKindFilter(this.label, this.kind);

  final String label;

  /// Null for [all], which matches everything.
  final AppointmentKind? kind;

  bool matches(Appointment appointment) =>
      kind == null || appointment.kind == kind;
}

/// One consultation on an appointment list.
///
/// **One entity for both roles.** A patient's list and a doctor's list are the
/// same rows read from opposite ends, and the only thing that differs is who
/// the other person is — which is why the field is [counterpartName] rather
/// than `doctorName` or `patientName`. Two entities would be two mappers, two
/// cards and two chances for the doctor's list to end up showing the doctor's
/// own name, which is exactly the bug the call screen had.
class Appointment {
  const Appointment({
    required this.id,
    required this.counterpartName,
    required this.mode,
    required this.status,
    required this.requestedAt,
    this.kind = AppointmentKind.instant,
    this.scheduledAt,
    this.counterpartSubtitle = '',
    this.counterpartId,
    this.startedAt,
    this.endedAt,
    this.durationSeconds = 0,
    this.fee,
    this.rating,
    this.isAnonymous = false,
    this.channelId,
    this.concern,
    this.paymentId,
    this.paidAt,
    this.counterpartRegistrationNumber,
    this.paymentStatus,
    this.paymentMethod,
    this.amountPaid,
    this.platformFee,
    this.refundedAmount = 0,
  });

  // --- The receipt ---------------------------------------------------------
  //
  // A consultation that was paid for has to be able to produce a receipt. Two
  // rules ask for it and they ask for different things: the NMC Telemedicine
  // Practice Guidelines want the practitioner's registration number on the fee
  // receipt, and a patient chasing a bank statement wants the transaction
  // reference. Both live here rather than being fetched separately, because the
  // history row already carries the fee and the date.
  //
  // All three are nullable: a consultation that never connected was never
  // charged, and an older row predates the API returning them.

  /// The gateway's payment reference — Razorpay's `pay_xxxxxxxx`.
  ///
  /// What a patient quotes when a charge is queried, and the only field on the
  /// receipt that ties it to a line on their bank statement.
  final String? paymentId;

  /// When the payment succeeded, which is not always when the consultation
  /// happened — a booking is paid for when it is made.
  final DateTime? paidAt;

  /// The doctor's medical council registration number, on a patient's row.
  ///
  /// Null on the doctor's own list, where the counterpart is a patient and has
  /// no registration to show.
  final String? counterpartRegistrationNumber;

  /// True when there is a receipt worth opening: money changed hands.
  ///
  /// Deliberately keyed on the fee rather than the status. A cancelled
  /// consultation that was charged and refunded still has a receipt, and a
  /// completed one that was free does not.
  bool get hasReceipt => (fee ?? 0) > 0;

  /// Where the money stands. Null on an older row the API sent without it, in
  /// which case [effectivePaymentStatus] infers what it can.
  final PaymentStatus? paymentStatus;

  /// `upi`, `card`, `netbanking`… Null until the gateway's webhook says.
  final String? paymentMethod;

  /// The total charged, platform fee included. Null when unknown, in which
  /// case [fee] is what was charged.
  final int? amountPaid;

  final int? platformFee;

  /// Whole rupees given back.
  final int refundedAmount;

  /// [paymentStatus], or a best guess from the older fields: a row with a
  /// payment reference was paid; a charged row without one is unconfirmed.
  PaymentStatus? get effectivePaymentStatus {
    if (paymentStatus case final status?) return status;
    if (!hasReceipt) return null;
    if (paymentId != null || paidAt != null) return PaymentStatus.paid;
    return null;
  }

  /// The total, `₹520`, falling back to the doctor's fee.
  String? get totalLabel => switch (amountPaid ?? fee) {
    final amount? => '₹$amount',
    null => null,
  };

  /// `UPI`, `Card`, `Net banking` — or null.
  String? get paymentMethodLabel => switch (paymentMethod) {
    null || '' => null,
    'upi' => 'UPI',
    'card' => tr('Card'),
    'netbanking' => tr('Net banking'),
    'wallet' => tr('Wallet'),
    'emi' => 'EMI',
    final other => '${other[0].toUpperCase()}${other.substring(1)}',
  };

  /// What the patient wrote about why they are consulting.
  ///
  /// On the doctor's list it is the reason they are looking at the row at all,
  /// and on an anonymous consultation the only thing they are told about the
  /// person. On the patient's own list it is what they said, which is what
  /// makes one past consultation tellable from another.
  final String? concern;

  /// Instant or scheduled. Defaults to instant, which is what every row was
  /// before booking existed.
  final AppointmentKind kind;

  /// When the consultation is booked for, on a scheduled one. Null on an
  /// instant consultation, which happens when a doctor answers.
  final DateTime? scheduledAt;

  final String id;

  /// Whoever is on the *other* end: the doctor, for a patient's list; the
  /// patient, for a doctor's.
  final String counterpartName;

  /// One line under the name — a speciality on the patient's list, and empty on
  /// the doctor's, where a patient has no title to give.
  final String counterpartSubtitle;

  /// Their id, for a row that leads somewhere. Null on an anonymous
  /// consultation, where linking two of them together is the one thing
  /// anonymity promises not to do.
  final String? counterpartId;

  final ConsultationMode mode;
  final AppointmentStatus status;

  final DateTime requestedAt;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// How long the call actually ran, per the server's clock.
  final int durationSeconds;

  /// What it cost, in whole rupees, fixed when the doctor accepted. Null for
  /// one that never got that far.
  final int? fee;

  /// Out of five, or null when the patient did not rate it.
  final int? rating;

  final bool isAnonymous;

  /// The WebRTC room, and only while the consultation could still be joined.
  /// Its presence is what puts a Rejoin button on the row.
  final String? channelId;

  bool get isLive => status.outcome == AppointmentOutcome.pending;

  /// True when there is a call to walk back into.
  ///
  /// A booking is excluded until its time comes round: it carries a channel
  /// from the moment it is made, and a Rejoin button on Tuesday for a Thursday
  /// appointment is a button that cannot work. The API refuses the join outside
  /// the same window and is the authority.
  bool get isRejoinable => isRejoinableAt();

  /// [now] is injectable for the same reason [isUpcoming]'s is: this reads the
  /// clock, and a test that cannot set it is a test that passes until the date
  /// it hard-coded goes by. One here did exactly that — it asserted a Thursday
  /// appointment was not yet joinable, and started failing the moment that
  /// Thursday was in the past.
  bool isRejoinableAt({DateTime? now}) {
    if (channelId == null || !isLive) return false;

    if (kind == AppointmentKind.scheduled) {
      final due = scheduledAt;
      return due != null &&
          !due.subtract(joinLead).isAfter(now ?? DateTime.now());
    }

    return true;
  }

  /// How early a booking may be opened. Matches
  /// `ConsultationsService.bookingLeadMs` on the API, which is the copy that
  /// decides — a button that appears before the server will accept the join is
  /// a button that fails.
  static const Duration joinLead = Duration(minutes: 15);

  /// True when this has not happened yet.
  ///
  /// Two different questions behind one answer: an instant consultation is
  /// upcoming while it is still in flight, and a booking is upcoming until its
  /// time passes. Treating both as "still pending" is what left a Thursday
  /// appointment off a list headed Upcoming.
  bool isUpcoming({DateTime? now}) {
    if (scheduledAt case final at? when kind == AppointmentKind.scheduled) {
      return isLive && at.isAfter(now ?? DateTime.now());
    }
    return isLive;
  }

  /// When this appointment is *for*: the booked time on a scheduled one, and
  /// when it started or was asked for on an instant one. What a list sorts by.
  DateTime get occursAt => scheduledAt ?? startedAt ?? requestedAt;

  /// `Video · 12 min` / `Audio · Cancelled`
  String get detailLabel {
    final parts = <String>[
      tr(mode.shortLabel),
      if (durationSeconds > 0) durationLabel else tr(status.label),
    ];

    return parts.join(' · ');
  }

  /// `12 min` / `48 sec` / `1 h 04 min`
  String get durationLabel {
    if (durationSeconds <= 0) return '—';

    if (durationSeconds < 60) {
      return tr('{seconds} sec', {'seconds': durationSeconds});
    }

    final minutes = durationSeconds ~/ 60;
    if (minutes < 60) return tr('{minutes} min', {'minutes': minutes});

    final hours = minutes ~/ 60;
    return tr('{hours} h {minutes} min', {
      'hours': hours,
      'minutes': (minutes % 60).toString().padLeft(2, '0'),
    });
  }

  /// `Sep 11, 2026 · 10:30 AM`
  ///
  /// On a booking this is the time it is *for*, not the time it was made —
  /// which is the only one either party has any use for.
  String get whenLabel {
    final at = occursAt;
    return '${AppDateFormat.monthDayYear(at)} · '
        '${AppDateFormat.clockTime(at)}';
  }

  /// `Today · 10:30 AM` / `Tomorrow · 9:00 AM` — for a row that has not
  /// happened yet, where the date matters less than how soon it is.
  String relativeWhenLabel({DateTime? now}) {
    final at = occursAt;
    return '${AppDateFormat.dayLabel(at, now: now)} · '
        '${AppDateFormat.clockTime(at)}';
  }

  /// `₹500`, or null when nothing was charged.
  String? get feeLabel => fee == null ? null : '₹$fee';
}
