import 'dart:ui';

/// Window size classes, following the Material 3 breakpoint system.
enum DeviceType {
  /// Phones in portrait — the primary target.
  compact,

  /// Large phones in landscape, small tablets.
  medium,

  /// Tablets and desktop windows.
  expanded,
}

class AppBreakpoints {
  const AppBreakpoints._();

  /// The frame the Figma designs were drawn against. Every dimension token is
  /// expressed in these design pixels and scaled from here.
  static const Size designSize = Size(402, 874);

  static const double compactMaxWidth = 600;
  static const double mediumMaxWidth = 840;

  /// Phone layouts are not stretched edge to edge on tablets — content is
  /// capped at this width and centred instead.
  static const double contentMaxWidth = 480;

  /// Scaling is clamped so a 320pt phone stays legible and a tablet does not
  /// end up with cartoonishly large controls.
  static const double minWidthScale = 0.82;
  static const double maxWidthScale = 1.20;
  static const double minHeightScale = 0.80;
  static const double maxHeightScale = 1.15;
  static const double minTextScale = 0.88;
  static const double maxTextScale = 1.12;

  static DeviceType deviceTypeFor(double width) {
    if (width < compactMaxWidth) return DeviceType.compact;
    if (width < mediumMaxWidth) return DeviceType.medium;
    return DeviceType.expanded;
  }
}
