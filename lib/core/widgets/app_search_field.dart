import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// A pill-shaped search input.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.enabled = true,
    this.autofocus = false,
  });

  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// Opens the keyboard as soon as the field appears — for a screen the
  /// patient reached by tapping a search bar.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      height: sizing.searchFieldHeight,
      padding: EdgeInsets.symmetric(horizontal: sizing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusPill),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: sizing.iconXs,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: sizing.spacingXs),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              autofocus: autofocus,
              textInputAction: TextInputAction.search,
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
              ),
              onChanged: onChanged,
            ),
          ),
          // Only offered once there is something to clear.
          if (controller.text.isNotEmpty)
            Semantics(
              button: true,
              label: tr('Clear search'),
              child: InkWell(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                customBorder: const CircleBorder(),
                child: Icon(
                  Icons.close_rounded,
                  size: sizing.iconXs,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
