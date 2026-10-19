import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../domain/entities/fee_breakdown.dart';

/// The itemised charge, with the total set apart below a rule.
class FeeBreakdownCard extends StatelessWidget {
  const FeeBreakdownCard({super.key, required this.fees});

  final FeeBreakdown fees;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Fee Breakdown'), style: sizing.text.listTitle),
          SizedBox(height: sizing.spacingSm),
          _Line(
            label: 'Consultation Fee',
            value: fees.formattedConsultationFee,
          ),
          SizedBox(height: sizing.spacingSm),
          // Only when there is one. The platform charges no fee at present,
          // and a "Platform Fee ₹0" line reads as a charge waiting to happen.
          if (fees.platformFee > 0) ...[
            _Line(label: 'Platform Fee', value: fees.formattedPlatformFee),
            SizedBox(height: sizing.spacingSm),
          ],
          Container(height: sizing.hairline, color: AppColors.border),
          SizedBox(height: sizing.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(tr('Total Amount'), style: sizing.text.sectionTitle),
              Text(fees.formattedTotal, style: sizing.text.amountTotal),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            tr(label),
            style: sizing.text.screenSubtitle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Text(value, style: sizing.text.fieldAffix),
      ],
    );
  }
}
