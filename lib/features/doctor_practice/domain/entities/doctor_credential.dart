import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';

/// What review made of one document.
enum CredentialDecision {
  pending('Awaiting review'),
  accepted('Accepted'),
  rejected('Rejected');

  const CredentialDecision(this.label);

  final String label;

  static CredentialDecision from(String? value) => switch (value) {
    'accepted' => CredentialDecision.accepted,
    'rejected' => CredentialDecision.rejected,
    _ => CredentialDecision.pending,
  };
}

/// Which piece of paperwork this is.
enum CredentialType {
  degree('Degree certificate'),
  registration('Council registration'),
  idProof('Photo ID'),
  photo('Photograph'),

  /// Anything the doctor adds to their own profile after registration — a
  /// fellowship, a diploma, a board membership. The other four are the
  /// registration's own paperwork, filed once and fixed, which is why they are
  /// named individually and this one is not.
  certificate('Additional certificate');

  const CredentialType(this.label);

  final String label;

  /// True for the ones the doctor filed with their registration, which are not
  /// theirs to remove: the approval rests on them.
  bool get isRegistrationDocument => this != CredentialType.certificate;

  static CredentialType from(String? value) => switch (value) {
    'registration' => CredentialType.registration,
    'id_proof' => CredentialType.idProof,
    'photo' => CredentialType.photo,
    'certificate' => CredentialType.certificate,
    _ => CredentialType.degree,
  };
}

/// One document backing a registration, as the doctor sees their own.
///
/// **No link to the file, but a way to it.** The bytes are fetched over the
/// same bearer token as this record, from `/doctors/me/documents/:id/file` —
/// never a URL in the payload, because a URL that exists is a URL that outlives
/// the request it was minted for, and this is identity paperwork.
///
/// Being able to look is not a nicety: a doctor who filed two scans cannot
/// otherwise tell which one a reviewer rejected, and the note that says "the
/// registration number is not legible" is unanswerable without the page it is
/// about.
class DoctorCredential {
  const DoctorCredential({
    required this.id,
    required this.type,
    required this.fileName,
    required this.sizeBytes,
    required this.uploadedAt,
    this.mimeType = 'application/octet-stream',
    this.title,
    this.decision = CredentialDecision.pending,
    this.note,
    this.reviewedAt,
  });

  final String id;
  final CredentialType type;

  /// What the doctor called it, on a certificate they added themselves.
  ///
  /// The claim under review, and the exact string that appears on their public
  /// profile once it is accepted — the file itself never leaves the private
  /// bucket. Null on the registration's own documents, whose type is their
  /// name.
  final String? title;

  /// What to call this on screen. The doctor's own words where there are any,
  /// because the category tells them nothing they did not already know.
  String get displayTitle =>
      title?.trim().isNotEmpty == true ? title!.trim() : type.label;

  /// True when the doctor may withdraw it. Only their own additions: the
  /// registration's paperwork is what the approval rests on.
  bool get isRemovable => type == CredentialType.certificate;
  final String fileName;
  final int sizeBytes;
  final DateTime uploadedAt;

  /// `application/pdf`, `image/jpeg`. What the viewer decides on — a scan
  /// saved with no extension is common, so the file name cannot answer it.
  final String mimeType;

  final CredentialDecision decision;

  /// The reviewer's note. For a rejection it is the only thing that tells the
  /// doctor what to change, which is why it is carried and their name is not:
  /// the decision is the platform's, not an individual's.
  final String? note;

  final DateTime? reviewedAt;

  /// `1.4 MB` / `860 KB`
  String get sizeLabel {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeBytes >= 1024) return '${(sizeBytes / 1024).round()} KB';

    return '$sizeBytes B';
  }

  /// `Uploaded Sep 2, 2026`
  String get uploadedLabel =>
      tr('Uploaded {date}', {'date': AppDateFormat.monthDayYear(uploadedAt)});
}

/// Reading a credential, for the sheet that shows one.
extension CredentialFile on DoctorCredential {
  bool get isPdf => mimeType == 'application/pdf';

  bool get isImage => mimeType.startsWith('image/');

  /// The API path the bytes come from.
  String get filePath => '/doctors/me/documents/$id/file';
}
