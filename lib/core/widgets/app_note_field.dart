import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import 'app_field_shell.dart';
import '../l10n/tr.dart';

/// A labelled multi-line text input in the app's form style — the long-answer
/// counterpart to `AppTextField`.
class AppNoteField extends StatelessWidget {
  const AppNoteField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.maxLength,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool enabled;

  /// Caps the entry when the backend has a limit worth enforcing here.
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AppFieldShell(
      label: label,
      errorText: errorText,
      // Tall enough for three lines of the design's placeholder.
      height: sizing.h(88),
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: sizing.spacingSm),
        child: TextField(
          controller: controller,
          enabled: enabled,
          maxLength: maxLength,
          // Grows with the text and scrolls inside the box once it is full,
          // instead of pushing the layout around.
          maxLines: null,
          expands: true,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
          textAlignVertical: TextAlignVertical.top,
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
        ),
      ),
    );
  }
}
