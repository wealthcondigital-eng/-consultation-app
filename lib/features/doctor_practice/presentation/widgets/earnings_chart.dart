import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/doctor_earnings.dart';

/// The period's takings as a row of bars.
///
/// Hand-drawn from `Container`s rather than a charting package. There is one
/// chart in this app, it has one series and no interaction, and a dependency
/// for it would be a dependency to keep current for the life of the project.
/// Every bar in range is drawn, including the empty ones — a chart that skips a
/// quiet Tuesday draws it as though it never happened, and the shape of the
/// week is the thing the chart is for.
class EarningsChart extends StatelessWidget {
  const EarningsChart({super.key, required this.earnings});

  final DoctorEarnings earnings;

  /// More than this and the labels collide, so every other one is dropped.
  static const int _labelEvery = 8;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final buckets = earnings.buckets;

    if (buckets.isEmpty) return const SizedBox.shrink();

    final peak = earnings.peak;
    final showEveryLabel = buckets.length <= _labelEvery;

    return SizedBox(
      height: sizing.h(140),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (index, bucket) in buckets.indexed)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: sizing.r(2)),
                child: _Bar(
                  // Clamped to a visible minimum, so a day with a single
                  // consultation is a short bar rather than nothing at all.
                  fraction: peak == 0
                      ? 0
                      : (bucket.gross / peak).clamp(0.0, 1.0),
                  label: showEveryLabel || index.isEven ? bucket.label : '',
                  isEmpty: bucket.gross == 0,
                  semanticLabel:
                      tr('{label}: ₹{amount}, {count} consultations', {
                        'label': bucket.label,
                        'amount': bucket.gross,
                        'count': bucket.consultations,
                      }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.label,
    required this.isEmpty,
    required this.semanticLabel,
  });

  final double fraction;
  final String label;
  final bool isEmpty;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      label: semanticLabel,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // A floor of four logical pixels, so an empty day still reads
                // as a bar at zero rather than as a missing column.
                final height = isEmpty
                    ? sizing.r(4)
                    : (constraints.maxHeight * fraction).clamp(
                        sizing.r(6),
                        constraints.maxHeight,
                      );

                return Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: height,
                    decoration: BoxDecoration(
                      color: isEmpty
                          ? AppColors.dividerFaint
                          : AppColors.primary,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(sizing.radiusXs),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: sizing.spacingXxs),
          // Fixed height whether or not there is a label, so dropping every
          // other one does not make the bars different lengths.
          SizedBox(
            height: sizing.h(14),
            child: FittedBox(
              child: Text(
                label,
                style: sizing.text.metaLabel.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
