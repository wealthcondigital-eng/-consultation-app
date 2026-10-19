/// What a doctor agrees to be pinged about.
class DoctorSettings {
  const DoctorSettings({
    this.newConsultations = true,
    this.chatMessages = true,
    this.payouts = true,
    this.platformUpdates = false,
  });

  /// Whether a patient's request may ring this doctor's phone.
  ///
  /// Not decoration. The matcher on the API reads it when choosing who to
  /// offer a consultation to, so switching it off actually stops the calls —
  /// which is what the row says it does, and the reason it carries a warning
  /// rather than sitting quietly among the others.
  final bool newConsultations;

  final bool chatMessages;

  /// When a payout is sent.
  final bool payouts;

  final bool platformUpdates;

  DoctorSettings copyWith({
    bool? newConsultations,
    bool? chatMessages,
    bool? payouts,
    bool? platformUpdates,
  }) {
    return DoctorSettings(
      newConsultations: newConsultations ?? this.newConsultations,
      chatMessages: chatMessages ?? this.chatMessages,
      payouts: payouts ?? this.payouts,
      platformUpdates: platformUpdates ?? this.platformUpdates,
    );
  }
}

/// One switch on the doctor's settings screen.
///
/// An enum rather than four hand-written rows, so the screen is a loop and a
/// fifth preference is one entry here plus one field above.
enum DoctorNotificationToggle {
  newConsultations(
    'Incoming consultations',
    'Let patients reach you when you are online. Turning this off stops '
        'consultations being offered to you.',
    isCritical: true,
  ),
  chatMessages(
    'Chat messages',
    'When a patient replies in a consultation thread.',
  ),
  payouts('Payouts', 'When money is sent to your account.'),
  platformUpdates(
    'Platform updates',
    'Occasional news and policy changes. Off by default.',
  );

  const DoctorNotificationToggle(
    this.label,
    this.description, {
    this.isCritical = false,
  });

  final String label;
  final String description;

  /// True for the one switch that changes whether the doctor can work. The
  /// screen marks it, because turning it off by accident looks exactly like the
  /// platform having gone quiet.
  final bool isCritical;

  bool from(DoctorSettings settings) => switch (this) {
    DoctorNotificationToggle.newConsultations => settings.newConsultations,
    DoctorNotificationToggle.chatMessages => settings.chatMessages,
    DoctorNotificationToggle.payouts => settings.payouts,
    DoctorNotificationToggle.platformUpdates => settings.platformUpdates,
  };

  DoctorSettings applyTo(DoctorSettings settings, bool value) => switch (this) {
    DoctorNotificationToggle.newConsultations => settings.copyWith(
      newConsultations: value,
    ),
    DoctorNotificationToggle.chatMessages => settings.copyWith(
      chatMessages: value,
    ),
    DoctorNotificationToggle.payouts => settings.copyWith(payouts: value),
    DoctorNotificationToggle.platformUpdates => settings.copyWith(
      platformUpdates: value,
    ),
  };

  /// The single-field body `PATCH /doctors/me/settings` expects. One key, not
  /// four: a screen that sent every switch could undo a change made elsewhere
  /// between the read and the write.
  Map<String, Object?> payload(bool value) => {name: value};
}

/// Where a doctor is paid, as they are shown it back.
///
/// The account number comes back **masked** and nothing here can un-mask it. A
/// payout destination is worth confirming and not worth re-reading in full: a
/// screenshot of a settings screen should not carry a whole account number, and
/// the doctor already knows their own. Re-entering it is how it changes.
class BankAccountSummary {
  const BankAccountSummary({
    this.isSet = false,
    this.bankName,
    this.accountHolderName,
    this.accountNumberMasked,
    this.routingCode,
    this.upiId,
  });

  const BankAccountSummary.none()
    : isSet = false,
      bankName = null,
      accountHolderName = null,
      accountNumberMasked = null,
      routingCode = null,
      upiId = null;

  final bool isSet;
  final String? bankName;
  final String? accountHolderName;

  /// `•••• 6789`
  final String? accountNumberMasked;

  final String? routingCode;
  final String? upiId;

  /// `HDFC Bank · •••• 6789`, or an invitation when nothing is on file.
  String get summaryLabel {
    if (!isSet) return 'Not set up yet';

    return [
      bankName,
      accountNumberMasked,
    ].whereType<String>().where((part) => part.isNotEmpty).join(' · ');
  }
}
