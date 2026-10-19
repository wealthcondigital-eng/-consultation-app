/// How a consultation is priced, and what the wizard's fee step holds.
///
/// **Two fees, not one.** The screen used to collect a single amount and write
/// it to both `videoFee` and `audioFee`, which priced a voice call the same as
/// a video one. A voice call is cheaper to give and cheaper to take, and
/// doctors price it that way — so each is entered on its own, and the API
/// accepts either field without the other.
class PracticeSetup {
  const PracticeSetup({
    this.feeOptions = defaultFeeOptions,
    this.videoFee,
    this.audioFee,
    this.currencySymbol = '₹',
    this.percentComplete = 0,
  });

  /// The fees offered as one-tap choices.
  ///
  /// Defaulted rather than left empty, and that is a bug fix: the options came
  /// from the backend read, so a failed load left the screen with no chips, no
  /// value, a permanently disabled Continue and nothing said about why. The
  /// list is presentation — the API has no opinion about it — so the app owns
  /// it and the screen works offline.
  final List<int> feeOptions;

  static const List<int> defaultFeeOptions = [200, 300, 500, 700, 1000, 1500];

  /// The platform's suggestion for a doctor who has not chosen yet.
  static const int suggestedVideoFee = 500;

  /// Audio is suggested lower than video for the same reason it is a separate
  /// field. A doctor is free to set them equal.
  static const int suggestedAudioFee = 300;

  static const int minFee = 1;
  static const int maxFee = 100000;

  /// Null until the doctor picks one. Deliberately **not** defaulted to the
  /// suggestion in the entity: a default written into the record is
  /// indistinguishable from a price the doctor actually chose, and the two mean
  /// different things to whoever bills against them. The screen seeds the
  /// suggestion into the *form*, which is a different thing.
  final int? videoFee;

  final int? audioFee;

  final String currencySymbol;

  /// How far through the wizard the doctor is, 0–100.
  final int percentComplete;

  /// `₹500`
  String formatFee(int amount) => '$currencySymbol$amount';

  String get videoFeeLabel => switch (videoFee) {
    final fee? => formatFee(fee),
    null => '—',
  };

  String get audioFeeLabel => switch (audioFee) {
    final fee? => formatFee(fee),
    null => '—',
  };

  /// What the profile row shows: both, or the one that is set.
  ///
  /// `₹700 video · ₹400 audio`, `₹500` when they match, `—` before either.
  String get selectedFeeLabel {
    if (videoFee == null && audioFee == null) return '—';
    if (videoFee == audioFee) return formatFee(videoFee!);
    if (audioFee == null) return '${formatFee(videoFee!)} video';
    if (videoFee == null) return '${formatFee(audioFee!)} audio';

    return '${formatFee(videoFee!)} video · ${formatFee(audioFee!)} audio';
  }

  /// `60% Completed`
  String get progressLabel => '$percentComplete% Completed';

  /// 0–1, for the progress bar.
  double get progress => (percentComplete / 100).clamp(0.0, 1.0);

  PracticeSetup copyWith({
    int? videoFee,
    int? audioFee,
    int? percentComplete,
    bool clearVideoFee = false,
    bool clearAudioFee = false,
  }) {
    return PracticeSetup(
      feeOptions: feeOptions,
      videoFee: clearVideoFee ? null : videoFee ?? this.videoFee,
      audioFee: clearAudioFee ? null : audioFee ?? this.audioFee,
      currencySymbol: currencySymbol,
      percentComplete: percentComplete ?? this.percentComplete,
    );
  }
}

/// Which of the two fees a control is editing.
///
/// An enum rather than two hand-written halves of the screen, so the second
/// field is a loop iteration instead of a second copy of the first — which is
/// how the two would drift.
enum ConsultationFeeKind {
  video(
    'Video consultation',
    'Face to face on a video call.',
    PracticeSetup.suggestedVideoFee,
  ),
  audio(
    'Audio consultation',
    'A voice call. Usually priced below video.',
    PracticeSetup.suggestedAudioFee,
  );

  const ConsultationFeeKind(this.label, this.description, this.suggested);

  final String label;
  final String description;

  /// What the form seeds when nothing is stored.
  final int suggested;

  int? from(PracticeSetup setup) => switch (this) {
    ConsultationFeeKind.video => setup.videoFee,
    ConsultationFeeKind.audio => setup.audioFee,
  };

  PracticeSetup applyTo(PracticeSetup setup, int? fee) => switch (this) {
    ConsultationFeeKind.video =>
      fee == null
          ? setup.copyWith(clearVideoFee: true)
          : setup.copyWith(videoFee: fee),
    ConsultationFeeKind.audio =>
      fee == null
          ? setup.copyWith(clearAudioFee: true)
          : setup.copyWith(audioFee: fee),
  };

  /// Why this fee cannot be saved, or null when it can.
  ///
  /// Null is not an error here — a doctor may price one kind and leave the
  /// other unset. `ManagePracticeSetup` is what refuses *both* being unset.
  String? errorFor(PracticeSetup setup) {
    final fee = from(setup);
    if (fee == null) return null;

    if (fee < PracticeSetup.minFee) {
      return 'A consultation fee has to be at least '
          '${setup.formatFee(PracticeSetup.minFee)}.';
    }
    if (fee > PracticeSetup.maxFee) {
      return 'That fee is higher than the platform allows.';
    }

    return null;
  }
}
