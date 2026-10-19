import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';

/// Reassurance about how the submitted data is handled.
class ComplianceFooter extends StatelessWidget {
  const ComplianceFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '\u{1F512} ${tr('DPDP Act 2023 Compliant')}',
          textAlign: TextAlign.center,
          style: sizing.text.complianceBadge,
        ),
        SizedBox(height: sizing.spacingXs),
        Text(
          tr(
            'Your data is encrypted and stored securely. You can request data '
            'deletion anytime from Settings.',
          ),
          textAlign: TextAlign.center,
          style: sizing.text.complianceNote,
        ),
      ],
    );
  }
}
