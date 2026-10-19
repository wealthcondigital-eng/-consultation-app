/// The stages the patient sees while a doctor is being found, in order.
enum MatchingStep {
  searching('Searching available doctors'),
  checking('Checking doctor availability'),
  connecting('Connecting securely');

  const MatchingStep(this.label);

  final String label;

  /// What the step says when the patient chose the doctor themselves —
  /// nothing is being searched for then; that doctor is being called. In
  /// English, as a `tr()` key; `{name}` is filled in by the widget.
  String get labelForChosenDoctor => switch (this) {
    MatchingStep.searching => 'Calling {name}',
    MatchingStep.checking => 'Waiting for the doctor to answer',
    MatchingStep.connecting => 'Connecting securely',
  };
}

/// How far along a step is.
enum MatchingStepStatus { pending, active, done }
