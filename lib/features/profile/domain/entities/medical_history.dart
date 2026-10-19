import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';

/// What the patient has recorded about their own health.
///
/// The patient's account of themselves, not a clinical record: it is what they
/// type on the medical-history form, and what the doctor is shown as context at
/// the start of a consultation. Nothing a doctor writes lands here — a
/// prescription belongs to the consultation that produced it, not to a field
/// the patient can edit afterwards.
///
/// [lastUpdated] is null until the record has been saved once. The summary line
/// quotes it, because a list of conditions with no date on it is a list nobody
/// knows whether to trust.
class MedicalHistory {
  const MedicalHistory({
    this.conditions = const [],
    this.medications = const [],
    this.allergies = const [],
    this.surgeries = const [],
    this.notes,
    this.lastUpdated,
  });

  const MedicalHistory.empty()
    : conditions = const [],
      medications = const [],
      allergies = const [],
      surgeries = const [],
      notes = null,
      lastUpdated = null;

  /// Ongoing conditions, e.g. `Asthma`, `Seasonal Allergies`.
  final List<String> conditions;

  /// Medication the patient is currently on, e.g. `Albuterol Inhaler`.
  final List<String> medications;

  /// What they react to. Kept apart from [conditions] because it is the one
  /// list a doctor scans before prescribing anything.
  final List<String> allergies;

  /// Past procedures, e.g. `Appendectomy, 2018`.
  final List<String> surgeries;

  /// Anything that does not fit a list.
  final String? notes;

  final DateTime? lastUpdated;

  bool get isEmpty =>
      conditions.isEmpty &&
      medications.isEmpty &&
      allergies.isEmpty &&
      surgeries.isEmpty &&
      (notes == null || notes!.trim().isEmpty);

  bool get isNotEmpty => !isEmpty;

  /// How many of the five sections have something in them. What the form's
  /// progress line counts.
  int get filledSections => [
    conditions.isNotEmpty,
    medications.isNotEmpty,
    allergies.isNotEmpty,
    surgeries.isNotEmpty,
    notes != null && notes!.trim().isNotEmpty,
  ].where((filled) => filled).length;

  static const int sectionCount = 5;

  /// `Asthma & Seasonal Allergies`
  String get conditionsLabel => switch (conditions.length) {
    0 => tr('No recorded conditions'),
    1 => conditions.single,
    _ =>
      '${conditions.sublist(0, conditions.length - 1).join(', ')} '
          '& ${conditions.last}',
  };

  /// `Last updated Oct 12, 2024. Active prescriptions include Albuterol
  /// Inhaler.`
  ///
  /// Each sentence is dropped when it has nothing to say, so a record with only
  /// conditions does not read as though the medication list were empty on
  /// purpose.
  String get summary {
    final sentences = <String>[
      if (lastUpdated case final date?)
        tr('Last updated {date}.', {'date': AppDateFormat.monthDayYear(date)})
      else
        tr('Not recorded yet.'),
      if (medications.isNotEmpty)
        tr('Active prescriptions include {list}.', {
          'list': medications.join(', '),
        }),
      if (allergies.isNotEmpty)
        tr('Allergic to {list}.', {'list': allergies.join(', ')}),
    ];

    return sentences.join(' ');
  }

  MedicalHistory copyWith({
    List<String>? conditions,
    List<String>? medications,
    List<String>? allergies,
    List<String>? surgeries,
    String? notes,
    bool clearNotes = false,
  }) {
    return MedicalHistory(
      conditions: conditions ?? this.conditions,
      medications: medications ?? this.medications,
      allergies: allergies ?? this.allergies,
      surgeries: surgeries ?? this.surgeries,
      notes: clearNotes ? null : notes ?? this.notes,
      lastUpdated: lastUpdated,
    );
  }

  /// The body `PUT /patients/me/medical-history` expects.
  ///
  /// snake_case for `notes`? No — the *fields* stay as the API names them, and
  /// this endpoint names them plainly. `updated_at` is deliberately absent: the
  /// server stamps it, and a client-supplied modification time is not one to
  /// trust.
  Map<String, Object?> toPayload() => {
    'conditions': conditions,
    'medications': medications,
    'allergies': allergies,
    'surgeries': surgeries,
    'notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
  };
}

/// Which list a chip belongs to. Drives one editor widget over four sections
/// rather than four near-identical ones.
enum MedicalHistorySection {
  conditions('Conditions', 'e.g. Asthma', 'Ongoing diagnoses you live with.'),
  medications(
    'Medications',
    'e.g. Albuterol Inhaler',
    'Anything you take regularly, with the dose if you know it.',
  ),
  allergies(
    'Allergies',
    'e.g. Penicillin',
    'What you react to. A doctor reads this before prescribing.',
  ),
  surgeries(
    'Procedures',
    'e.g. Appendectomy, 2018',
    'Operations and procedures you have had.',
  );

  const MedicalHistorySection(this.label, this.hint, this.help);

  final String label;
  final String hint;
  final String help;

  List<String> from(MedicalHistory history) => switch (this) {
    MedicalHistorySection.conditions => history.conditions,
    MedicalHistorySection.medications => history.medications,
    MedicalHistorySection.allergies => history.allergies,
    MedicalHistorySection.surgeries => history.surgeries,
  };

  MedicalHistory applyTo(
    MedicalHistory history,
    List<String> values,
  ) => switch (this) {
    MedicalHistorySection.conditions => history.copyWith(conditions: values),
    MedicalHistorySection.medications => history.copyWith(medications: values),
    MedicalHistorySection.allergies => history.copyWith(allergies: values),
    MedicalHistorySection.surgeries => history.copyWith(surgeries: values),
  };
}
