import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';

/// What a document on the record is.
///
/// Two values, not a taxonomy. The only distinction that changes how a document
/// is read is whether it tells a doctor what the patient is currently taking;
/// everything else is evidence and sorts by date.
/// Declared prescription-first: the list renders the values in this order, and
/// what the patient is currently taking is what a doctor opens the record for.
enum MedicalRecordKind {
  prescription('Prescription', 'Prescriptions'),
  report('Report', 'Reports & documents');

  const MedicalRecordKind(this.label, this.sectionTitle);

  /// One word, for the badge on a row.
  final String label;

  /// The heading over its group in the list.
  final String sectionTitle;

  /// The value the API carries. Tolerant of an absent or unknown one, which
  /// reads as an ordinary report — the safe default, because it is what every
  /// document was before this distinction existed.
  static MedicalRecordKind from(Object? value) => switch (value) {
    'prescription' => MedicalRecordKind.prescription,
    _ => MedicalRecordKind.report,
  };

  String get key => name;
}

/// Who added a document to the record.
///
/// Deliberately **not** a trust level. There is no verified flag and no
/// approval step: a patient may photograph a printout from any clinic and a
/// doctor may issue one here, and both belong on the record. This only says
/// which happened, so a doctor reading it knows what they are looking at.
enum MedicalRecordAuthor {
  patient('Added by you', 'Added by patient'),
  doctor('Added by doctor', 'Added by you');

  const MedicalRecordAuthor(this.patientLabel, this.doctorLabel);

  /// How it reads on the patient's own screen.
  final String patientLabel;

  /// How the same row reads to the doctor.
  final String doctorLabel;

  static MedicalRecordAuthor from(Object? value) => switch (value) {
    'doctor' => MedicalRecordAuthor.doctor,
    _ => MedicalRecordAuthor.patient,
  };

  String get key => name;
}

/// A document the patient has uploaded to their record — a lab result, a scan,
/// a prescription from somewhere else.
///
/// Kept apart from [MedicalHistory], which is what the patient *types*. The two
/// answer different questions: the history is the summary a doctor reads in the
/// first thirty seconds of a call, and a report is the evidence behind one line
/// of it. Merging them would bury a four-word allergy under a 2 MB scan.
class MedicalReport {
  const MedicalReport({
    required this.id,
    required this.title,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.uploadedAt,
    this.kind = MedicalRecordKind.report,
    this.addedBy = MedicalRecordAuthor.patient,
  });

  /// Whether this is a prescription or an ordinary document.
  ///
  /// The distinction is not cosmetic. A doctor opening a record in the first
  /// minute of a call wants the current prescription, not a two-year-old scan,
  /// and a list that cannot tell them apart makes them open both.
  final MedicalRecordKind kind;

  /// Who put it on the record.
  ///
  /// Recorded rather than enforced: both sides may add a prescription, and
  /// nothing here marks one as verified or more trustworthy than the other. It
  /// exists so a doctor can see at a glance whether the patient uploaded a
  /// photograph of a printout or a doctor on this platform issued it.
  final MedicalRecordAuthor addedBy;

  final String id;

  /// What the patient called it, or the file's own name when they did not
  /// bother naming it.
  final String title;

  final String fileName;

  /// `application/pdf`, `image/jpeg`. Decides which viewer opens it and which
  /// glyph the row carries.
  final String mimeType;

  final int sizeBytes;
  final DateTime uploadedAt;

  bool get isPdf => mimeType == 'application/pdf';

  bool get isImage => mimeType.startsWith('image/');

  /// The API path the bytes come from, behind the session's token.
  String get filePath => '/patients/me/reports/$id/file';

  /// `1.4 MB` / `860 KB`
  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) return '${(sizeBytes / 1024).round()} KB';

    return '$sizeBytes B';
  }

  /// `Added Sep 21, 2026 · 1.4 MB`
  String get detailLabel => tr('Added {date} · {size}', {
    'date': AppDateFormat.monthDayYear(uploadedAt),
    'size': sizeLabel,
  });

  /// `Sep 21, 2026 · 1.4 MB · Added by doctor`
  ///
  /// [asDoctor] flips the authorship wording, because the same row is read from
  /// both ends and "Added by you" has to mean whoever is holding the phone.
  String detailLabelFor({required bool asDoctor}) {
    final author = asDoctor ? addedBy.doctorLabel : addedBy.patientLabel;
    return '${AppDateFormat.monthDayYear(uploadedAt)} · $sizeLabel · '
        '${tr(author)}';
  }
}
