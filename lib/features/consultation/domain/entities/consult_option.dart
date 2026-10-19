import '../../../../core/l10n/tr.dart';

/// The kinds of consultation a patient can start.
enum ConsultOptionKind { instant, scheduled }

/// One way to reach a doctor, as offered on the consult options screen.
class ConsultOption {
  const ConsultOption({
    required this.kind,
    required this.title,
    required this.description,
    required this.actionLabel,
    this.estimatedWait,
    this.note,
    this.isAvailable = true,
  });

  final ConsultOptionKind kind;
  final String title;
  final String description;

  /// Label on the option's button.
  final String actionLabel;

  /// How long before a doctor picks up. Only meaningful for
  /// [ConsultOptionKind.instant].
  final Duration? estimatedWait;

  /// A short supporting line under the title, used where there is no wait to
  /// quote — e.g. "Book slots for later today or tomorrow".
  final String? note;

  /// False when the option cannot be started right now, e.g. no physician is
  /// on shift.
  final bool isAvailable;

  /// `Estimated Wait: ~4 mins`, or null when there is no wait to show.
  String? get estimatedWaitLabel {
    final wait = estimatedWait;
    if (wait == null) return null;

    final minutes = wait.inMinutes;
    if (minutes < 1) return tr('Estimated Wait: under a minute');
    return minutes == 1
        ? tr('Estimated Wait: ~{minutes} min', {'minutes': minutes})
        : tr('Estimated Wait: ~{minutes} mins', {'minutes': minutes});
  }
}
