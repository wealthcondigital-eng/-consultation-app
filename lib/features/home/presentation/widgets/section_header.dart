import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/l10n/tr.dart';

/// A section title, optionally with an action link on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;

  /// Both null on a section with nowhere else to go.
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            tr(title),
            style: sizing.text.sectionTitle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (actionLabel case final actionLabel?)
          TextButton(
            onPressed: onActionTap,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: sizing.spacingXs),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(tr(actionLabel), style: sizing.text.sectionAction),
          ),
      ],
    );
  }
}
