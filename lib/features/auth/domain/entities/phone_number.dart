import 'country.dart';

/// A phone number as the user is entering it: a country plus the raw national
/// digits, with no formatting characters.
class PhoneNumber {
  const PhoneNumber({required this.country, this.nationalDigits = ''});

  final Country country;

  /// Digits only — the display formatting lives in the presentation layer.
  final String nationalDigits;

  bool get isEmpty => nationalDigits.isEmpty;

  /// Complete enough to send an OTP to.
  bool get isValid => nationalDigits.length == country.digitCount;

  /// E.164 form, e.g. `+919876543210`.
  String get e164 => '${country.dialCode}$nationalDigits';

  /// The number grouped for display, e.g. `98765 43210`.
  String get formattedNational => formatDigits(nationalDigits, country);

  PhoneNumber copyWith({Country? country, String? nationalDigits}) {
    return PhoneNumber(
      country: country ?? this.country,
      nationalDigits: nationalDigits ?? this.nationalDigits,
    );
  }

  /// Chunks [digits] according to the country's grouping, ignoring any digits
  /// beyond the expected length.
  static String formatDigits(String digits, Country country) {
    final buffer = StringBuffer();
    var index = 0;

    for (final group in country.digitGroups) {
      if (index >= digits.length) break;
      if (index > 0) buffer.write(' ');

      final end = (index + group).clamp(0, digits.length);
      buffer.write(digits.substring(index, end));
      index = end;
    }

    return buffer.toString();
  }

  @override
  bool operator ==(Object other) =>
      other is PhoneNumber &&
      other.country == country &&
      other.nationalDigits == nationalDigits;

  @override
  int get hashCode => Object.hash(country, nationalDigits);
}
