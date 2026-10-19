import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// A hairline rule with a label in the middle — "———  OR  ———".
class LabelledDivider extends StatelessWidget {
  const LabelledDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final rule = Expanded(
      child: Container(height: sizing.hairline, color: AppColors.border),
    );

    return Row(
      children: [
        rule,
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sizing.spacingSm),
          child: Text(tr(label), style: sizing.text.dividerLabel),
        ),
        rule,
      ],
    );
  }
}
