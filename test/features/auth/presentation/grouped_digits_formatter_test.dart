import 'package:consultation_app/features/auth/domain/entities/country.dart';
import 'package:consultation_app/features/auth/presentation/widgets/grouped_digits_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TextEditingValue _value(String text, [int? caret]) {
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret ?? text.length),
  );
}

void main() {
  const formatter = GroupedDigitsFormatter(Country.india);

  TextEditingValue format(String from, String to, [int? caret]) {
    return formatter.formatEditUpdate(_value(from), _value(to, caret));
  }

  test('inserts the group separator as the user types', () {
    expect(format('9876', '98765').text, '98765');
    expect(format('98765', '987654').text, '98765 4');
  });

  test('caps input at the country digit count', () {
    final result = format('98765 43210', '98765 432109');

    expect(result.text, '98765 43210');
  });

  test('strips anything that is not a digit', () {
    expect(format('', '(987) 65-43210').text, '98765 43210');
  });

  test('treats a pasted dial code as national digits, then caps', () {
    // The field already owns the country, so a pasted +91 is just more digits
    // and gets truncated at the national length rather than silently dropped.
    expect(format('', '+91 98765 43210').text, '91987 65432');
  });

  test('keeps the caret anchored to the digit the user typed', () {
    // Typing a digit at the start of a full number.
    final result = format('98765 43210', '198765 43210', 1);

    expect(result.text, '19876 54321');
    expect(result.selection.baseOffset, 1);
  });

  test('handles deleting back across a separator', () {
    final result = format('98765 4', '98765 ', 6);

    expect(result.text, '98765');
    expect(result.selection.baseOffset, 5);
  });
}
