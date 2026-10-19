import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';
import 'app_search_field.dart';

/// A labelled field that opens a bottom sheet of options.
///
/// Replaces `DropdownButton`, whose menu floats over the field in a style of
/// its own. A sheet matches how the app already asks for a country, and gives
/// each option a full-width target — which matters more on a phone than the
/// few pixels a dropdown saves.
class AppSelectField<T> extends StatelessWidget {
  const AppSelectField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.errorText,
  });

  final String label;

  /// Shown when nothing is selected yet.
  final String hint;

  final T? value;

  /// Option to display label, in the order they should appear.
  final Map<T, String> options;

  final ValueChanged<T?> onChanged;
  final bool enabled;
  final String? errorText;

  Future<void> _open(BuildContext context) async {
    final picked = await AppOptionSheet.show<T>(
      context,
      title: label,
      options: options,
      selected: value,
    );

    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final selected = value;
    final hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(label), style: sizing.text.fieldLabel),
        SizedBox(height: sizing.spacingSm),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? () => _open(context) : null,
            borderRadius: BorderRadius.circular(sizing.radiusInput),
            child: Ink(
              height: sizing.inputHeight,
              padding: EdgeInsets.symmetric(horizontal: sizing.w(16)),
              decoration: BoxDecoration(
                color: enabled ? AppColors.surface : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(sizing.radiusInput),
                border: Border.all(
                  color: hasError ? AppColors.danger : AppColors.border,
                  width: sizing.borderWidth,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(selected == null ? hint : options[selected] ?? hint),
                      style: selected == null
                          ? sizing.text.fieldPlaceholder
                          : sizing.text.fieldValue,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: sizing.iconMd,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (errorText case final error?) ...[
          SizedBox(height: sizing.spacingSm),
          Text(tr(error), style: sizing.text.error),
        ],
      ],
    );
  }
}

/// The sheet [AppSelectField] opens. Returns the picked value, or null when
/// dismissed without choosing.
class AppOptionSheet<T> extends StatelessWidget {
  const AppOptionSheet({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final Map<T, String> options;
  final T? selected;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required Map<T, String> options,
    T? selected,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      // A long list must not push the sheet past the top of the screen.
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizing.radiusLg),
        ),
      ),
      builder: (_) =>
          AppOptionSheet<T>(title: title, options: options, selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) =>
      _OptionSheetBody<T>(title: title, options: options, selected: selected);
}

/// The sheet's contents. Stateful for the search box, which appears once a
/// list is too long to scan — every state in India, or a big state's cities.
class _OptionSheetBody<T> extends StatefulWidget {
  const _OptionSheetBody({
    required this.title,
    required this.options,
    required this.selected,
  });

  final String title;
  final Map<T, String> options;
  final T? selected;

  @override
  State<_OptionSheetBody<T>> createState() => _OptionSheetBodyState<T>();
}

class _OptionSheetBodyState<T> extends State<_OptionSheetBody<T>> {
  /// Above this many options the sheet offers a search box.
  static const int _searchFrom = 10;

  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final searchable = widget.options.length > _searchFrom;

    final needle = _query.text.trim().toLowerCase();
    final entries = [
      for (final entry in widget.options.entries)
        if (needle.isEmpty ||
            entry.value.toLowerCase().contains(needle) ||
            tr(entry.value).toLowerCase().contains(needle))
          entry,
    ];

    return SafeArea(
      // Clear of the keyboard while searching.
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  sizing.screenPaddingH,
                  sizing.spacingXs,
                  sizing.screenPaddingH,
                  sizing.spacingMd,
                ),
                child: Text(tr(widget.title), style: sizing.text.navTitle),
              ),
              if (searchable)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    sizing.screenPaddingH,
                    0,
                    sizing.screenPaddingH,
                    sizing.spacingSm,
                  ),
                  child: AppSearchField(
                    hint: tr('Search'),
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              Flexible(
                child: entries.isEmpty
                    ? Padding(
                        padding: EdgeInsets.all(sizing.spacingLg),
                        child: Text(
                          tr('No matches'),
                          textAlign: TextAlign.center,
                          style: sizing.text.bodySmall,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.only(bottom: sizing.spacingMd),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          final isSelected = entry.key == widget.selected;

                          return _OptionRow(
                            label: entry.value,
                            isSelected: isSelected,
                            onTap: () => Navigator.of(context).pop(entry.key),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: sizing.screenPaddingH,
          vertical: sizing.spacingSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                tr(label),
                style: isSelected
                    ? sizing.text.fieldValue.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      )
                    : sizing.text.fieldValue,
              ),
            ),
            // Only the chosen row is marked, so the eye lands on it without
            // a column of empty circles to scan past.
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: sizing.iconMd,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
