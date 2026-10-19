import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';

/// What the appointment comes to: how long it runs, and what it costs.
class BookingSummaryCard extends StatelessWidget {
  const BookingSummaryCard({
    super.key,
    required this.durationLabel,
    required this.feeLabel,
    this.appointmentLabel,
  });

  final String durationLabel;
  final String feeLabel;

  /// The chosen day and time. Null until a slot is picked.
  final String? appointmentLabel;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusMd),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Column(
        children: [
          if (appointmentLabel case final label?) ...[
            _SummaryRow(label: 'Appointment', value: label),
            _Divider(),
          ],
          _SummaryRow(label: 'Duration', value: durationLabel),
          _Divider(),
          _SummaryRow(
            label: 'Consultation Fee',
            value: feeLabel,
            isTotal: true,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: sizing.spacingSm),
      child: Divider(height: sizing.hairline, color: AppColors.border),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;

  /// The fee carries the emphasis; everything above it is plain detail.
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      children: [
        Expanded(
          child: Text(
            tr(label),
            style: sizing.text.screenSubtitle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: sizing.spacingSm),
        Flexible(
          child: Text(
            value,
            style: isTotal ? sizing.text.amountTotal : sizing.text.fieldAffix,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
