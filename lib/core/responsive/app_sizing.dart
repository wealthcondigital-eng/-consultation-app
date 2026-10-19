import 'package:flutter/widgets.dart';

import '../theme/app_text_styles.dart';
import 'app_breakpoints.dart';

/// Every dimension in the app, resolved for the current screen.
///
/// Design values live here and nowhere else — screens and widgets read tokens
/// (`sizing.buttonHeight`, `sizing.spacingXl`) instead of hard-coding numbers,
/// so a device of any size gets a proportional layout for free.
///
/// Obtain it with `context.sizing`. It is provided once at the app root by
/// [AppSizingScope] and rebuilds whenever the window is resized or rotated.
@immutable
class AppSizing {
  const AppSizing._({
    required this.screenSize,
    required this.deviceType,
    required this.widthScale,
    required this.heightScale,
    required this.textScale,
  });

  /// Derives the scale factors for [screenSize] against the design frame.
  factory AppSizing.fromSize(Size screenSize) {
    final design = AppBreakpoints.designSize;
    final deviceType = AppBreakpoints.deviceTypeFor(screenSize.width);

    // On tablets the content column is capped, so scale against that cap
    // rather than the full window width.
    final effectiveWidth = screenSize.width > AppBreakpoints.contentMaxWidth
        ? AppBreakpoints.contentMaxWidth
        : screenSize.width;

    final rawWidthScale = effectiveWidth / design.width;
    final rawHeightScale = screenSize.height / design.height;

    return AppSizing._(
      screenSize: screenSize,
      deviceType: deviceType,
      widthScale: rawWidthScale.clamp(
        AppBreakpoints.minWidthScale,
        AppBreakpoints.maxWidthScale,
      ),
      heightScale: rawHeightScale.clamp(
        AppBreakpoints.minHeightScale,
        AppBreakpoints.maxHeightScale,
      ),
      // Type scales on the geometric mean of both axes so text does not jump
      // when only one dimension changes (e.g. on rotation).
      textScale: ((rawWidthScale + rawHeightScale) / 2).clamp(
        AppBreakpoints.minTextScale,
        AppBreakpoints.maxTextScale,
      ),
    );
  }

  final Size screenSize;
  final DeviceType deviceType;

  /// Multiplier for horizontal design pixels.
  final double widthScale;

  /// Multiplier for vertical design pixels.
  final double heightScale;

  /// Multiplier for font sizes. The user's own system text scaling is applied
  /// by Flutter on top of this and is deliberately not folded in here.
  final double textScale;

  bool get isCompact => deviceType == DeviceType.compact;
  bool get isTablet => deviceType == DeviceType.expanded;

  /// Scales a horizontal design value.
  double w(double designPx) => designPx * widthScale;

  /// Scales a vertical design value.
  double h(double designPx) => designPx * heightScale;

  /// Scales a font size.
  double sp(double designPx) => designPx * textScale;

  /// Scales a value that must stay square (icons, avatars, radii).
  double r(double designPx) => designPx * widthScale;

  /// Text styles resolved at this screen's type scale.
  AppTextStyles get text => AppTextStyles(scale: textScale);

  // --- Spacing scale -------------------------------------------------------
  double get spacingXxs => h(4);
  double get spacingXs => h(8);
  double get spacingSm => h(12);
  double get spacingMd => h(16);
  double get spacingLg => h(20);
  double get spacingXl => h(24);
  double get spacingXxl => h(32);
  double get spacingXxxl => h(40);

  // --- Layout --------------------------------------------------------------
  /// Horizontal gutter used by every screen.
  double get screenPaddingH => w(24);
  double get screenPaddingV => h(24);

  EdgeInsets get screenPadding => EdgeInsets.symmetric(
    horizontal: screenPaddingH,
    vertical: screenPaddingV,
  );

  double get contentMaxWidth => AppBreakpoints.contentMaxWidth;

  // --- Radii and strokes ---------------------------------------------------
  double get radiusXs => r(4);
  double get radiusSm => r(8);

  /// Form inputs sit between the small and medium radii in the design.
  double get radiusInput => r(10);
  double get radiusMd => r(12);
  double get radiusLg => r(16);
  double get radiusXl => r(20);

  /// The rounded top of a sheet that rises over a full-bleed background — the
  /// form panel on the auth screens. Larger than [radiusXl]: the curve has a
  /// whole screen width to travel across, and at 20 it reads as a clipped
  /// corner rather than as a sheet lifting off the surface behind it.
  double get sheetRadius => r(28);

  /// Fully rounded ends — chips, search fields, pills.
  double get radiusPill => 100;
  double get borderWidth => 1.5;

  /// Border on a selected or filled control.
  double get borderWidthEmphasis => 2;

  /// Input borders and dividers. Deliberately unscaled — a hairline should
  /// stay a hairline on every device.
  double get hairline => 1;

  BorderRadius get borderRadiusMd => BorderRadius.circular(radiusMd);

  // --- Components ----------------------------------------------------------
  double get buttonHeight => h(48);
  double get inputHeight => h(52);

  /// Form fields stacked in a list are shorter than a standalone input.
  double get fieldHeight => h(48);
  double get searchFieldHeight => h(44);
  double get checkboxSize => r(16);

  /// A filter or choice pill.
  double get chipHeight => h(32);

  /// A button that sits inside a card rather than spanning the screen.
  double get buttonHeightCompact => h(34);
  double get iconXs => r(16);
  double get iconSm => r(20);
  double get iconMd => r(24);

  /// Top bar with a back affordance and a title.
  double get topBarHeight => h(56);
  double get iconButtonSize => r(32);

  /// One digit box in the OTP row.
  double get otpBoxWidth => r(48);
  double get otpBoxHeight => r(56);

  /// Cards on a scrolling page.
  double get cardPadding => r(16);

  /// Roomier padding for a card that is the focus of its screen.
  double get cardPaddingLarge => r(24);
  double get tilePadding => r(12);

  /// Rounded square holding a card's leading glyph.
  double get iconChipSize => r(48);

  /// Avatars, icon badges and speciality glyph circles.
  double get avatarSize => r(40);
  double get avatarSizeLarge => r(64);
  double get iconLg => r(18);

  /// A radio control in a selectable row.
  double get radioSize => r(20);

  double get navBarHeight => h(76);

  /// Onboarding brand mark — the tinted circle and the cross inside it.
  double get brandBadgeSize => r(220);
  double get brandMarkSize => r(96);
  double get brandMarkStroke => r(3);

  /// The same mark on the auth screens, where it identifies the app without
  /// taking the half-page the onboarding badge does — the form is the point of
  /// those screens, and on a short phone with the keyboard up the large badge
  /// pushed the number field off the screen entirely.
  double get brandBadgeSizeCompact => r(72);
  double get brandMarkSizeCompact => r(34);

  /// The mark on the landing hero — between the splash badge above and the
  /// compact auth badge below, so the three entry screens step down in size
  /// rather than cutting between two.
  double get brandBadgeSizeHero => r(140);
  double get brandMarkSizeHero => r(64);

  @override
  bool operator ==(Object other) =>
      other is AppSizing && other.screenSize == screenSize;

  @override
  int get hashCode => screenSize.hashCode;
}

/// Provides the resolved [AppSizing] to the widget tree.
///
/// Install once, above the navigator, via `MaterialApp.builder`.
class AppSizingScope extends StatelessWidget {
  const AppSizingScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // LayoutBuilder rather than MediaQuery so the sizing also reacts to being
    // embedded in a smaller box (split screen, previews, golden tests).
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest.isFinite
            ? constraints.biggest
            : MediaQuery.sizeOf(context);

        return _InheritedAppSizing(
          sizing: AppSizing.fromSize(size),
          child: child,
        );
      },
    );
  }
}

class _InheritedAppSizing extends InheritedWidget {
  const _InheritedAppSizing({required this.sizing, required super.child});

  final AppSizing sizing;

  @override
  bool updateShouldNotify(_InheritedAppSizing oldWidget) =>
      oldWidget.sizing != sizing;
}

extension AppSizingContext on BuildContext {
  /// The dimension tokens for the current screen.
  AppSizing get sizing {
    final scope = dependOnInheritedWidgetOfExactType<_InheritedAppSizing>();
    assert(
      scope != null,
      'AppSizingScope is missing. Wrap the app with it in MaterialApp.builder.',
    );
    return scope?.sizing ?? AppSizing.fromSize(MediaQuery.sizeOf(this));
  }

  /// Text styles for the current screen.
  AppTextStyles get textStyles => sizing.text;
}
