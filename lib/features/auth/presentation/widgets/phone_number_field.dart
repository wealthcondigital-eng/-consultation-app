import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/country.dart';
import 'grouped_digits_formatter.dart';

/// Labelled phone input: the dialling code, a divider, and the number.
class PhoneNumberField extends StatelessWidget {
  const PhoneNumberField({
    super.key,
    required this.controller,
    required this.country,
    required this.onDigitsChanged,
    this.onSubmitted,
    this.enabled = true,
    this.errorText,
  });

  final TextEditingController controller;

  /// Fixes the dialling code, the grouping and the expected length. Shown, not
  /// chosen: the app serves one country.
  final Country country;

  /// Reports digits only, with the display grouping stripped.
  final ValueChanged<String> onDigitsChanged;

  final VoidCallback? onSubmitted;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Phone Number'), style: sizing.text.fieldLabel),
        SizedBox(height: sizing.spacingXs),
        Container(
          height: sizing.inputHeight,
          padding: EdgeInsets.symmetric(horizontal: sizing.spacingMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: sizing.borderRadiusMd,
            border: Border.all(
              width: sizing.hairline,
              color: hasError ? AppColors.danger : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              _DialCodePrefix(country: country),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: sizing.spacingSm),
                child: SizedBox(
                  height: sizing.r(18),
                  width: sizing.hairline,
                  child: ColoredBox(color: AppColors.border),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  style: sizing.text.fieldValue,
                  cursorColor: AppColors.primary,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    GroupedDigitsFormatter(country),
                  ],
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: country.sampleNumber,
                    hintStyle: sizing.text.fieldValue.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  onChanged: (value) =>
                      onDigitsChanged(value.replaceAll(RegExp(r'\D'), '')),
                  onSubmitted: (_) => onSubmitted?.call(),
                ),
              ),
            ],
          ),
        ),
        if (hasError) ...[
          SizedBox(height: sizing.spacingXxs),
          Text(errorText!, style: sizing.text.error),
        ],
      ],
    );
  }
}

/// The flag and dialling code at the head of the field.
///
/// Read-only, and deliberately not a control: the app serves India, so a menu
/// here would have one item in it. Not a disabled button either — nothing
/// should invite a tap that does nothing. It keeps a spoken label so the code
/// is still announced, just not as something to activate.
class _DialCodePrefix extends StatelessWidget {
  const _DialCodePrefix({required this.country});

  final Country country;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      label: tr('Country code {code}', {'code': country.dialCode}),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(country.flag, style: sizing.text.fieldValue),
          SizedBox(width: sizing.spacingXxs),
          Text(country.dialCode, style: sizing.text.fieldAffix),
        ],
      ),
    );
  }
}
