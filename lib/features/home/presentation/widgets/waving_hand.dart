import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The 👋 in the greeting, waving once when the dashboard appears.
///
/// The motion is a sine wave rather than hand-picked keyframes, because that is
/// what a wave physically is: the hand rocks evenly about the wrist at a steady
/// rate. Keyframes with falling amplitudes read as a hand running out of
/// energy, not as someone saying hello.
///
/// Runs to completion rather than looping. A hand that never stops waving pulls
/// the eye off the screen's content for as long as the patient is on it, and a
/// repeating controller would also keep the tree permanently un-settled — which
/// hangs `pumpAndSettle` in every test that renders this screen.
class WavingHand extends StatefulWidget {
  const WavingHand({super.key, this.style});

  final TextStyle? style;

  /// Three rocks is a greeting; one is a twitch and six is a plea.
  static const double _cycles = 3;

  /// Roughly 18°. Far enough to read at this size, short of a windscreen wiper.
  static const double _amplitude = 0.32;

  @override
  State<WavingHand> createState() => _WavingHandState();
}

class _WavingHandState extends State<WavingHand>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    // ~3 rocks/second, which is about the rate a person actually waves.
    duration: const Duration(milliseconds: 1100),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Started here rather than in initState because it depends on the
    // reduce-motion setting, which needs an inherited MediaQuery.
    if (_started) return;
    _started = true;

    if (!MediaQuery.disableAnimationsOf(context)) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The rock, in radians.
  ///
  /// A half-sine envelope grows the swing and settles it again, so the hand
  /// starts and ends upright instead of snapping to and from full tilt. Both
  /// terms are zero at t=0 and t=1, which is what makes the rest position
  /// exact rather than approximate.
  double get _angle {
    final t = _controller.value;
    final envelope = math.sin(t * math.pi);
    final rock = math.sin(t * 2 * math.pi * WavingHand._cycles);

    return rock * envelope * WavingHand._amplitude;
  }

  @override
  Widget build(BuildContext context) {
    // Decorative: the greeting's own semantics already read the words, so an
    // announced emoji would only repeat them.
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        child: Text('\u{1F44B}', style: widget.style),
        builder: (context, child) => Transform.rotate(
          angle: _angle,
          // The wrist. On this glyph that is the bottom middle — rotating about
          // a corner drags the hand through an arc, which reads as flapping,
          // and about the centre it reads as spinning.
          alignment: Alignment.bottomCenter,
          child: child,
        ),
      ),
    );
  }
}
