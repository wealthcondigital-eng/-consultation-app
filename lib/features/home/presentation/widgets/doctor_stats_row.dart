import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/doctor_dashboard.dart';
import '../../../../core/l10n/tr.dart';

/// Today's four figures, two by two.
///
/// A grid rather than one row. Three cards across a 320pt phone already put
/// "Patients" on two lines; a fourth would have made every label wrap. Two rows
/// of two keeps each number legible at the width it is actually read at, and
/// leaves room for what a doctor most wants to know — what the day was worth.
class DoctorStatsRow extends StatelessWidget {
  const DoctorStatsRow({super.key, required this.stats});

  final DoctorDayStats stats;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // IntrinsicHeight so a wrapped label on one card lifts its neighbour
        // with it rather than leaving the pair ragged.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Consults',
                  value: '${stats.consults}',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.primaryDeep,
                ),
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: _StatCard(
                  label: 'Patients',
                  value: '${stats.patients}',
                  icon: Icons.groups_outlined,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: sizing.spacingXs),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Billed today',
                  value: stats.earningsLabel,
                  icon: Icons.payments_outlined,
                  color: AppColors.primaryVivid,
                ),
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: _StatCard(
                  label: 'Rating',
                  value: stats.ratingLabel,
                  icon: Icons.star_outline_rounded,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.tilePadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusMd),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: sizing.iconXs * 0.85, color: color),
              SizedBox(width: sizing.spacingXxs),
              Expanded(
                child: Text(
                  tr(label),
                  style: sizing.text.metaLabel.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: sizing.spacingXxs),
          // Shrink-to-fit rather than ellipsised: `₹1,24,000` is a number, and
          // half a number is worse than a smaller one.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: sizing.text.amountTotal.copyWith(color: color),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
