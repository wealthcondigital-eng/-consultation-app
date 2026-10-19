// Generates the launcher icons from the one source the app draws its mark
// from, so the icon on the home screen and the mark on the splash cannot drift
// apart. Not a test of behaviour — run it to regenerate the assets:
//
//   flutter test test/branding/generate_launcher_icons_test.dart --update-goldens
//
// It runs as an ordinary test too: without `--update-goldens` it fails if the
// checked-in icons no longer match the mark, which is exactly the reminder
// wanted when someone changes the logo and forgets the icons.
import 'package:consultation_app/core/theme/app_colors.dart';
import 'package:consultation_app/core/widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android's launcher densities, in pixels.
const _android = <String, int>{
  'mdpi': 48,
  'hdpi': 72,
  'xhdpi': 96,
  'xxhdpi': 144,
  'xxxhdpi': 192,
};

/// The adaptive foreground is drawn on a 108dp canvas of which only the middle
/// 72dp is guaranteed visible — the launcher crops the rest to whatever shape
/// the device uses. The mark is sized against that safe zone, not the canvas.
const _adaptive = <String, int>{
  'mdpi': 108,
  'hdpi': 162,
  'xhdpi': 216,
  'xxhdpi': 324,
  'xxxhdpi': 432,
};

/// Every slot in `AppIcon.appiconset`, file name to pixel size. The name
/// carries the point size and the scale; the value is what actually gets drawn.
const _iosIcons = <String, int>{
  'Icon-App-20x20@1x.png': 20,
  'Icon-App-20x20@2x.png': 40,
  'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29,
  'Icon-App-29x29@2x.png': 58,
  'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40,
  'Icon-App-40x40@2x.png': 80,
  'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120,
  'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76,
  'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

/// Renders [child] at exactly [pixels] square and writes it to [path].
Future<void> _render(
  WidgetTester tester, {
  required Widget child,
  required int pixels,
  required String path,
}) async {
  tester.view
    ..physicalSize = Size(pixels.toDouble(), pixels.toDouble())
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      // The icon is a fixed-pixel asset; the system text scale must not reach
      // it, and nothing about it should depend on the host device.
      data: const MediaQueryData(),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(child: child),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(RepaintBoundary).first,
    matchesGoldenFile(path),
  );
}

void main() {
  group('launcher icons', () {
    for (final entry in _android.entries) {
      testWidgets('android ${entry.key}', (tester) async {
        await _render(
          tester,
          pixels: entry.value,
          // The legacy icon carries its own tile, because a launcher older
          // than adaptive icons draws the bitmap as it is given.
          child: AppLogoTile(size: entry.value.toDouble()),
          path:
              '../../android/app/src/main/res/mipmap-${entry.key}'
              '/ic_launcher.png',
        );
      });
    }

    for (final entry in _adaptive.entries) {
      testWidgets('android adaptive foreground ${entry.key}', (tester) async {
        final canvas = entry.value.toDouble();

        await _render(
          tester,
          pixels: entry.value,
          // Transparent: the background layer is the brand colour, declared in
          // XML, and the launcher animates the two against each other.
          child: SizedBox.square(
            dimension: canvas,
            child: Center(
              // 40% of the canvas, which lands inside the 66% safe zone with
              // room for the parallax the launcher applies.
              child: AppLogoMark(size: canvas * 0.42, color: AppColors.onBrand),
            ),
          ),
          path:
              '../../android/app/src/main/res/mipmap-${entry.key}'
              '/ic_launcher_foreground.png',
        );
      });
    }

    // Every slot the asset catalogue declares. Generating only the 1024 would
    // leave the old Flutter icon on the home screen, in Settings and in
    // Spotlight — iOS reads each size separately and does not downscale one
    // for the rest.
    //
    // Drawn square: iOS applies the corner mask itself, and a pre-rounded
    // bitmap shows its own corners inside the system's.
    for (final entry in _iosIcons.entries) {
      testWidgets('ios ${entry.key}', (tester) async {
        await _render(
          tester,
          pixels: entry.value,
          child: AppLogoTile(size: entry.value.toDouble(), radiusFactor: 0),
          path:
              '../../ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry.key}',
        );
      });
    }
  });
}
