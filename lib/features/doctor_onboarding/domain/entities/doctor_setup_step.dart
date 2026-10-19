/// The three stages of doctor profile setup, in order.
enum DoctorSetupStep {
  uploadVerify('Upload & Verify', 'Verify Credentials'),
  details('Details', 'Professional Details'),
  bank('Bank', 'Bank Payout Account');

  const DoctorSetupStep(this.label, this.title);

  /// Short label in the stepper.
  final String label;

  /// Heading of the step's body.
  final String title;

  /// `1`, `2`, `3` — what the stepper shows before it is done.
  int get number => index + 1;

  DoctorSetupStep? get next =>
      index + 1 < values.length ? values[index + 1] : null;

  DoctorSetupStep? get previous => index > 0 ? values[index - 1] : null;
}
