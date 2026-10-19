import '../../../../core/l10n/tr.dart';

/// How a consultation is delivered.
enum ConsultationMode {
  video(
    'Video Consultation',
    'Video',
    'Face to face on a video call — best for anything the doctor should see.',
    'Video Call',
    'High-definition call',
  ),
  audio(
    'Audio Consultation',
    'Audio',
    'A voice call. Lighter on data and works on a weak connection.',
    'Voice Call',
    'Voice-only consultation',
  );

  const ConsultationMode(
    this.label,
    this.shortLabel,
    this.description,
    this.callLabel,
    this.callNote,
  );

  /// Full name, e.g. `Video Consultation`.
  final String label;

  /// One word, for tight spaces.
  final String shortLabel;

  /// What the patient gets, shown when they choose.
  final String description;

  /// How the call itself is named, e.g. `Voice Call` — for tighter controls
  /// than the mode sheet, where [label] and [description] do not fit.
  final String callLabel;

  /// One line under [callLabel].
  final String callNote;

  /// `Audio Call` — the call type named plainly, for a control that is choosing
  /// between the types themselves. [callLabel] is the friendlier name used
  /// where the call is being offered to the patient.
  String get callTypeLabel => switch (this) {
    ConsultationMode.video => tr('Video Call'),
    ConsultationMode.audio => tr('Audio Call'),
  };
}
