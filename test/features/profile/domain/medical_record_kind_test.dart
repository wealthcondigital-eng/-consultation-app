import 'package:consultation_app/features/profile/domain/entities/medical_report.dart';
import 'package:flutter_test/flutter_test.dart';

MedicalReport _report({
  MedicalRecordKind kind = MedicalRecordKind.report,
  MedicalRecordAuthor addedBy = MedicalRecordAuthor.patient,
}) {
  return MedicalReport(
    id: 'report-1',
    title: 'Blood work',
    fileName: 'blood-work.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 840000,
    uploadedAt: DateTime(2026, 9, 21),
    kind: kind,
    addedBy: addedBy,
  );
}

void main() {
  group('MedicalRecordKind', () {
    test('lists prescriptions first, which is the order the list renders', () {
      expect(MedicalRecordKind.values.first, MedicalRecordKind.prescription);
    });

    test('reads the API value', () {
      expect(
        MedicalRecordKind.from('prescription'),
        MedicalRecordKind.prescription,
      );
      expect(MedicalRecordKind.from('report'), MedicalRecordKind.report);
    });

    test('falls back to a report on anything it does not recognise', () {
      // What every document was before the distinction existed, so an older
      // row and a backend that does not send the field both read correctly.
      expect(MedicalRecordKind.from(null), MedicalRecordKind.report);
      expect(MedicalRecordKind.from('discharge'), MedicalRecordKind.report);
      expect(MedicalRecordKind.from(7), MedicalRecordKind.report);
    });

    test('defaults to a report when none is given', () {
      expect(_report().kind, MedicalRecordKind.report);
    });
  });

  group('MedicalRecordAuthor', () {
    test('reads the API value and defaults to the patient', () {
      expect(MedicalRecordAuthor.from('doctor'), MedicalRecordAuthor.doctor);
      expect(MedicalRecordAuthor.from('patient'), MedicalRecordAuthor.patient);
      expect(MedicalRecordAuthor.from(null), MedicalRecordAuthor.patient);
    });

    test('says "you" to whichever end is reading', () {
      final mine = _report(addedBy: MedicalRecordAuthor.patient);
      final theirs = _report(addedBy: MedicalRecordAuthor.doctor);

      expect(mine.detailLabelFor(asDoctor: false), contains('Added by you'));
      expect(mine.detailLabelFor(asDoctor: true), contains('Added by patient'));
      expect(
        theirs.detailLabelFor(asDoctor: false),
        contains('Added by doctor'),
      );
      expect(theirs.detailLabelFor(asDoctor: true), contains('Added by you'));
    });

    test('carries no verification state', () {
      // Deliberate: both sides may add a prescription and nothing approves
      // one. If a `verified` flag ever appears here, this test should be the
      // thing that argues about it.
      expect(MedicalRecordAuthor.values, hasLength(2));
    });
  });
}
