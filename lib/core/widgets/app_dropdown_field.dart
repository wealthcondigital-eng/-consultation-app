import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import 'app_field_shell.dart';
import '../l10n/tr.dart';

/// A labelled single-choice field in the app's form style.
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.errorText,
    this.enabled = true,
    this.leading,
  });

  final String label;

  /// Shown while nothing is selected.
  final String hint;

  final T? value;
  final List<T> items;

  /// How each option reads in the list and in the closed field.
  final String Function(T value) labelOf;

  final ValueChanged<T?> onChanged;
  final String? errorText;
  final bool enabled;

  /// Optional glyph before the value, matching the text fields.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AppFieldShell(
      label: label,
      errorText: errorText,
      leading: leading,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          enableFeedback: true,
          borderRadius: BorderRadius.circular(sizing.radiusInput),
          dropdownColor: AppColors.surface,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: sizing.iconXs,
            color: AppColors.textSecondary,
          ),
          hint: Text(tr(hint), style: sizing.text.fieldPlaceholder),
          style: sizing.text.fieldValue,
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: Text(tr(labelOf(item)), style: sizing.text.fieldValue),
              ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
