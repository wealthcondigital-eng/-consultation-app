import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/matching_step.dart';
import '../../domain/entities/matching_update.dart';

/// The checklist of stages, ticked off as matching progresses.
class MatchingSteps extends StatelessWidget {
  const MatchingSteps({super.key, required this.update, this.doctorName});

  final MatchingUpdate update;

  /// The doctor the patient chose, when they chose one — the steps then read
  /// as calling that doctor rather than searching for any.
  final String? doctorName;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in MatchingStep.values) ...[
          if (step != MatchingStep.values.first)
            SizedBox(height: sizing.spacingMd),
          _StepRow(
            label: doctorName == null
                ? tr(step.label)
                : tr(step.labelForChosenDoctor, {'name': doctorName}),
            status: update.statusOf(step),
          ),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.status});

  /// Already translated.
  final String label;
  final MatchingStepStatus status;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final isDone = status == MatchingStepStatus.done;

    return Semantics(
      label: '$label, ${tr(status.name)}',
      child: Row(
        children: [
          _Glyph(status: status),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Text(
              label,
              style: sizing.text.cardTitle.copyWith(
                fontWeight: FontWeight.w600,
                // A step not yet reached recedes.
                color: status == MatchingStepStatus.pending
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          if (isDone) const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _Glyph extends StatefulWidget {
  const _Glyph({required this.status});

  final MatchingStepStatus status;

  @override
  State<_Glyph> createState() => _GlyphState();
}

class _GlyphState extends State<_Glyph> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(_Glyph oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncSpin();
  }

  void _syncSpin() {
    if (widget.status == MatchingStepStatus.active) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final size = sizing.iconMd;

    final (background, foreground, icon) = switch (widget.status) {
      MatchingStepStatus.done => (
        AppColors.successSurface,
        AppColors.success,
        Icons.check_rounded,
      ),
      MatchingStepStatus.active => (
        AppColors.primarySurface,
        AppColors.primary,
        Icons.settings_rounded,
      ),
      MatchingStepStatus.pending => (
        AppColors.surfaceMuted,
        AppColors.textTertiary,
        Icons.circle_outlined,
      ),
    };

    final glyph = Icon(icon, size: size * 0.5, color: foreground);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: widget.status == MatchingStepStatus.active
          ? RotationTransition(turns: _spin, child: glyph)
          : glyph,
    );
  }
}
