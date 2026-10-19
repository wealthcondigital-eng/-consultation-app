import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/l10n/tr.dart';

/// The large tinted circle the review and approval screens are built around.
class StatusHero extends StatelessWidget {
  const StatusHero({
    super.key,
    required this.icon,
    required this.surface,
    required this.foreground,
    this.semanticsLabel,
  });

  final IconData icon;

  /// Fill of the circle.
  final Color surface;

  /// Colour of the glyph inside it.
  final Color foreground;

  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    // Capped against height as well as width: this is the tallest thing on
    // either screen, and it must not push the buttons off a short device.
    final diameter = sizing.r(200).clamp(0.0, sizing.h(200));

    return Semantics(
      label: switch (semanticsLabel) {
        final label? => tr(label),
        null => null,
      },
      child: Container(
        width: diameter,
        height: diameter,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: surface, shape: BoxShape.circle),
        child: Icon(icon, size: diameter * 0.4, color: foreground),
      ),
    );
  }
}
