import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import 'app_field_shell.dart';
import '../l10n/tr.dart';

/// A labelled single-line text input in the app's form style.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autofillHints,
    this.trailing,
    this.helperText,
    this.maxLength,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final String? errorText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  /// Optional glyph after the input, e.g. a tick on a verified value.
  final Widget? trailing;

  /// A note under the field. Hidden while an error is showing.
  final String? helperText;

  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AppFieldShell(
      label: label,
      errorText: errorText,
      trailing: trailing,
      helperText: helperText,
      child: Center(
        child: TextField(
          controller: controller,
          enabled: enabled,
          maxLength: maxLength,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          autofillHints: autofillHints,
          style: sizing.text.fieldValue,
          cursorColor: AppColors.primary,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: tr(hint),
            hintStyle: sizing.text.fieldPlaceholder,
            counterText: '',
          ),
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted?.call(),
        ),
      ),
    );
  }
}
