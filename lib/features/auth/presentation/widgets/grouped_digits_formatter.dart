import 'package:flutter/services.dart';

import '../../domain/entities/country.dart';
import '../../domain/entities/phone_number.dart';

/// Formats a phone field as the user types — `9876543210` becomes
/// `98765 43210` — and caps input at the country's expected length.
///
/// The caret is re-anchored by counting digits rather than characters, so
/// editing in the middle of the number behaves correctly.
class GroupedDigitsFormatter extends TextInputFormatter {
  const GroupedDigitsFormatter(this.country);

  final Country country;

  static final _nonDigit = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(_nonDigit, '');
    final capped = digits.length > country.digitCount
        ? digits.substring(0, country.digitCount)
        : digits;

    final formatted = PhoneNumber.formatDigits(capped, country);

    // How many digits sit before the caret in what the user just typed.
    final caret = newValue.selection.end.clamp(0, newValue.text.length);
    final digitsBeforeCaret = newValue.text
        .substring(0, caret)
        .replaceAll(_nonDigit, '')
        .length
        .clamp(0, capped.length);

    // Walk the formatted string until that many digits have been passed.
    var offset = 0;
    var seen = 0;
    while (offset < formatted.length && seen < digitsBeforeCaret) {
      if (!_nonDigit.hasMatch(formatted[offset])) seen++;
      offset++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
