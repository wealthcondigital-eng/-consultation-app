import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/profile_section.dart';

/// Which languages the doctor can consult in.
///
/// A multi-select chip wrap rather than a dropdown, because the answer is
/// usually two or three and a patient scanning a listing wants to see all of
/// them at once.
///
/// The list is the app's, and it is the twelve most-spoken languages in India
/// rather than all twenty-two scheduled ones — a wrap of twenty-two chips is a
/// screen of chips, and the ones left out are served by [onToggle] accepting
/// any string, so an entry from the backend that is not on this list still
/// renders as selected.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  /// What the doctor has chosen. Compared case-insensitively, so a value stored
  /// as `english` still lights up the `English` chip.
  final List<String> selected;

  final ValueChanged<String> onToggle;

  /// Offered as one-tap choices.
  static const List<String> common = [
    'English',
    'Hindi',
    'Bengali',
    'Marathi',
    'Telugu',
    'Tamil',
    'Gujarati',
    'Urdu',
    'Kannada',
    'Malayalam',
    'Odia',
    'Punjabi',
  ];

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final lowercased = selected.map((entry) => entry.toLowerCase()).toSet();

    // Anything stored that is not on the offered list still gets a chip, so a
    // doctor who was set up with `Assamese` does not silently lose it the first
    // time they open this form.
    final extras = selected.where(
      (entry) =>
          !common.any((option) => option.toLowerCase() == entry.toLowerCase()),
    );

    return ProfileSection(
      title: 'Languages',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('What you can hold a consultation in.'),
            style: sizing.text.helperText,
          ),
          SizedBox(height: sizing.spacingXs),
          Wrap(
            spacing: sizing.spacingXs,
            runSpacing: sizing.spacingXs,
            children: [
              for (final language in [...common, ...extras])
                _LanguageChip(
                  label: language,
                  isSelected: lowercased.contains(language.toLowerCase()),
                  onTap: () => onToggle(language),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      button: true,
      selected: isSelected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(sizing.radiusPill),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: sizing.spacingSm,
            vertical: sizing.spacingXs,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(sizing.radiusPill),
            border: Border.all(
              width: sizing.hairline,
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_rounded,
                  size: sizing.iconXs * 0.8,
                  color: Colors.white,
                ),
                SizedBox(width: sizing.spacingXxs),
              ],
              Text(
                tr(label),
                style: sizing.text.chipLabel.copyWith(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
