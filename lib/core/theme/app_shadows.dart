import 'package:flutter/material.dart';

/// Elevation, expressed as shadows rather than Material elevation so cards
/// match the design exactly.
class AppShadows {
  const AppShadows._();

  /// A raised card on a tinted page background.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// A small round control sitting on top of other content, e.g. the camera
  /// badge on a profile photo.
  static const List<BoxShadow> badge = [
    BoxShadow(color: Color(0x20000000), blurRadius: 6, offset: Offset(0, 2)),
  ];

  /// The selected segment of a switch, lifted just off its track.
  static const List<BoxShadow> segment = [
    BoxShadow(color: Color(0x0D0F172A), blurRadius: 2, offset: Offset(0, 1)),
  ];
}
