import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';

/// The spinner at the top of the matching screen: a tinted track with a brand
/// arc sweeping around it, and a glyph at rest in the middle.
class MatchingProgressRing extends StatefulWidget {
  const MatchingProgressRing({super.key, this.isSpinning = true});

  /// False once matching finishes, leaving a completed ring.
  final bool isSpinning;

  @override
  State<MatchingProgressRing> createState() => _MatchingProgressRingState();
}

class _MatchingProgressRingState extends State<MatchingProgressRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isSpinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(MatchingProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpinning) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final extent = sizing.r(160);

    return SizedBox.square(
      dimension: extent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size.square(extent),
                painter: _RingPainter(
                  rotation: _controller.value,
                  strokeWidth: sizing.r(8),
                  // A full ring reads as "done" once the sweep stops.
                  sweep: widget.isSpinning ? 0.7 : 1,
                ),
              );
            },
          ),
          Icon(
            Icons.monitor_heart_outlined,
            size: sizing.r(32),
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.rotation,
    required this.strokeWidth,
    required this.sweep,
  });

  /// 0..1 around the circle.
  final double rotation;
  final double strokeWidth;

  /// Fraction of the circle the brand arc covers.
  final double sweep;

  @override
  void paint(Canvas canvas, Size size) {
    // The design insets the 140pt ring inside a 160pt box.
    final inset = size.shortestSide * 0.0625 + strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.primarySurface;

    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = AppColors.primary;

    canvas.drawArc(
      rect,
      // Starts at twelve o'clock and rotates from there.
      -math.pi / 2 + rotation * math.pi * 2,
      math.pi * 2 * sweep,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.rotation != rotation || oldDelegate.sweep != sweep;
}
