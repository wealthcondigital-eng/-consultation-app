import '../../../../core/l10n/tr.dart';

/// The alias a patient consults under.
///
/// It is the only name the doctor ever sees, so it is validated as its own
/// value object rather than as a loose string on the booking.
class CodeName {
  const CodeName(this.value);

  final String value;

  static const int minLength = 3;
  static const int maxLength = 24;

  /// Whitespace-collapsed form — what is actually sent and shown.
  String get normalised => value.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get isEmpty => normalised.isEmpty;

  bool get isValid => validationError == null;

  /// Why this alias cannot be used, or null when it can.
  String? get validationError {
    final name = normalised;

    if (name.isEmpty) return tr('Enter a code name to consult under.');
    if (name.length < minLength) {
      return tr('Use at least {count} characters.', {'count': minLength});
    }
    if (name.length > maxLength) {
      return tr('Keep it under {count} characters.', {'count': maxLength});
    }
    // Anything but letters, digits, spaces, hyphens and apostrophes is more
    // likely a paste accident than a chosen alias.
    if (!RegExp(r"^[A-Za-z0-9 \-']+$").hasMatch(name)) {
      return tr('Letters, numbers, spaces and hyphens only.');
    }

    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is CodeName && other.normalised == normalised;

  @override
  int get hashCode => normalised.hashCode;

  @override
  String toString() => normalised;
}
