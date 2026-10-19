import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';

/// The bars standing in for a clip's audio.
///
/// The amplitude list is resampled to however many bars fit the width, so the
/// same clip reads correctly in a narrow bubble and in a full-width card.
class VoiceWaveform extends StatelessWidget {
  const VoiceWaveform({
    super.key,
    required this.amplitudes,
    required this.playedColor,
    required this.remainingColor,
    this.progress = 0,
    this.alignRight = false,
  });

  /// One value per bar, each between 0 and 1.
  final List<double> amplitudes;

  /// How far playback has got, 0 to 1.
  final double progress;

  final Color playedColor;
  final Color remainingColor;

  /// Fills from the right — used while recording, so the newest audio is at
  /// the leading edge.
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final barWidth = sizing.r(3);
    final gap = sizing.r(2);
    final height = sizing.h(28);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slots = max(
            1,
            ((constraints.maxWidth + gap) / (barWidth + gap)).floor(),
          );
          final bars = _resample(amplitudes, slots);
          final playedBars = (bars.length * progress.clamp(0.0, 1.0)).round();

          return Row(
            mainAxisAlignment: alignRight
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var index = 0; index < bars.length; index++) ...[
                if (index > 0) SizedBox(width: gap),
                Container(
                  width: barWidth,
                  // Never zero-height: a silent stretch still shows a tick.
                  height: max(sizing.r(2), bars[index] * height),
                  decoration: BoxDecoration(
                    color: index < playedBars ? playedColor : remainingColor,
                    borderRadius: BorderRadius.circular(barWidth),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Averages [values] down — or stretches them up — to [slots] bars.
  static List<double> _resample(List<double> values, int slots) {
    if (values.isEmpty) return const [];
    if (values.length <= slots) return values;

    final bucket = values.length / slots;

    return List<double>.generate(slots, (index) {
      final start = (index * bucket).floor();
      final end = min(values.length, ((index + 1) * bucket).ceil());

      var total = 0.0;
      for (var i = start; i < end; i++) {
        total += values[i];
      }

      return total / (end - start);
    });
  }
}
