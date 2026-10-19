import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/medical_history.dart';
import 'profile_section.dart';

/// One section of the medical-history form: the entries, and a field to add
/// another.
///
/// Chips rather than a paragraph. A doctor reads this in the first thirty
/// seconds of a consultation, and "Penicillin" as its own entry can be picked
/// out at a glance where "allergic to penicillin, I think" cannot. It also
/// makes removing one thing possible without re-typing the rest.
///
/// Holds its own `TextEditingController` — the entry field is transient state
/// that belongs to this widget, not to the record being edited. Clearing it on
/// submit is what makes adding three things in a row feel like a list.
class MedicalHistoryEditor extends StatefulWidget {
  const MedicalHistoryEditor({
    super.key,
    required this.section,
    required this.entries,
    required this.onAdd,
    required this.onRemove,
  });

  final MedicalHistorySection section;
  final List<String> entries;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  State<MedicalHistoryEditor> createState() => _MedicalHistoryEditorState();
}

class _MedicalHistoryEditorState extends State<MedicalHistoryEditor> {
  final TextEditingController _entry = TextEditingController();

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _entry.text.trim();
    if (value.isEmpty) return;

    widget.onAdd(value);
    _entry.clear();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return ProfileSection(
      title: widget.section.label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(widget.section.help), style: sizing.text.helperText),
          SizedBox(height: sizing.spacingXs),
          if (widget.entries.isNotEmpty) ...[
            Wrap(
              spacing: sizing.spacingXs,
              runSpacing: sizing.spacingXs,
              children: [
                for (final entry in widget.entries)
                  _EntryChip(
                    label: entry,
                    onRemove: () => widget.onRemove(entry),
                  ),
              ],
            ),
            SizedBox(height: sizing.spacingSm),
          ],
          _AddRow(
            controller: _entry,
            hint: widget.section.hint,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class _EntryChip extends StatelessWidget {
  const _EntryChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.only(
        left: sizing.spacingSm,
        right: sizing.spacingXxs,
        top: sizing.spacingXxs,
        bottom: sizing.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(sizing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Constrained so one very long entry wraps inside its own chip
          // instead of forcing the row wider than the screen.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: sizing.w(240)),
            child: Text(
              label,
              style: sizing.text.chipLabel.copyWith(
                color: AppColors.primaryDeep,
              ),
            ),
          ),
          SizedBox(width: sizing.spacingXxs),
          Semantics(
            button: true,
            label: tr('Remove {label}', {'label': label}),
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(sizing.spacingXxs / 2),
                child: Icon(
                  Icons.close_rounded,
                  size: sizing.iconXs * 0.8,
                  color: AppColors.primaryDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The entry field and its Add button.
///
/// The keyboard's own action submits as well, because adding four allergies
/// should not mean reaching for a button four times.
class _AddRow extends StatelessWidget {
  const _AddRow({
    required this.controller,
    required this.hint,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      children: [
        Expanded(
          child: Container(
            height: sizing.fieldHeight,
            padding: EdgeInsets.symmetric(horizontal: sizing.spacingSm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(sizing.radiusInput),
              border: Border.all(
                width: sizing.hairline,
                color: AppColors.border,
              ),
            ),
            alignment: Alignment.centerLeft,
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => onSubmit(),
              style: sizing.text.fieldValue,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: tr(hint),
                hintStyle: sizing.text.fieldPlaceholder,
              ),
            ),
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Semantics(
          button: true,
          label: tr('Add entry'),
          child: InkWell(
            onTap: onSubmit,
            borderRadius: BorderRadius.circular(sizing.radiusInput),
            child: Container(
              width: sizing.fieldHeight,
              height: sizing.fieldHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(sizing.radiusInput),
              ),
              child: Icon(
                Icons.add_rounded,
                size: sizing.iconSm,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
