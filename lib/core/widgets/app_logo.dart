import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app's mark: a consultation bubble with a medical cross cut out of it.
///
/// Two ideas in one silhouette. The bubble says this is a *conversation* —
/// which is the whole product, and the thing a plain cross never said; the
/// cross says what the conversation is about. A cross alone is the most
/// over-used mark in healthcare and reads as a pharmacy, a first-aid kit or a
/// hospital sign long before it reads as a doctor you can talk to.
///
/// The cross is a **hole**, not a second colour. One fill means the mark works
/// on the brand gradient, on white, in a notification tray and punched out of a
/// monochrome status bar without needing a variant for each — and a shape that
/// survives being reduced to one colour is a shape that survives being 18
/// pixels wide.
///
/// Drawn rather than shipped as a bitmap, so it stays crisp at every size the
/// responsive scale produces and can be recoloured by the caller.
class AppLogoMark extends StatelessWidget {
  const AppLogoMark({super.key, required this.size, this.color});

  /// The width of the mark. Height follows the aspect ratio below.
  final double size;

  /// What the bubble is filled with. The cross shows whatever is behind.
  final Color? color;

  /// Slightly taller than wide: the tail hangs below the body.
  static const double aspectRatio = 100 / 92;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size / aspectRatio,
      child: CustomPaint(
        painter: _LogoPainter(color: color ?? AppColors.primary),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.color});

  final Color color;

  /// The mark is designed on a 100 × 92 grid and scaled from there, so every
  /// proportion below is a fixed relationship rather than a number that has to
  /// be re-tuned per size.
  static const Size _grid = Size(100, 92);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _grid.width;
    canvas.save();
    canvas.scale(scale);

    canvas.drawPath(
      Path.combine(PathOperation.difference, _bubble(), _cross()),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );

    canvas.restore();
  }

  /// The rounded body plus the tail, as one shape.
  static Path _bubble() {
    final body = Path()
      ..addRRect(RRect.fromLTRBR(4, 2, 96, 70, const Radius.circular(24)));

    // Swept rather than a plain triangle: a straight-edged tail reads as a
    // bookmark at small sizes, and the curve is what makes it a speech bubble.
    final tail = Path()
      ..moveTo(26, 62)
      ..quadraticBezierTo(28, 86, 20, 90)
      ..quadraticBezierTo(44, 86, 54, 62)
      ..close();

    return Path.combine(PathOperation.union, body, tail);
  }

  /// The cut-out. Centred on the body, not on the whole mark — the tail is
  /// below it, and centring on the bounding box would push the cross low.
  static Path _cross() {
    const centreX = 50.0;
    const centreY = 36.0;
    const arm = 38.0;
    const thickness = 13.0;
    const radius = Radius.circular(3.5);

    final vertical = Path()
      ..addRRect(
        RRect.fromLTRBR(
          centreX - thickness / 2,
          centreY - arm / 2,
          centreX + thickness / 2,
          centreY + arm / 2,
          radius,
        ),
      );

    final horizontal = Path()
      ..addRRect(
        RRect.fromLTRBR(
          centreX - arm / 2,
          centreY - thickness / 2,
          centreX + arm / 2,
          centreY + thickness / 2,
          radius,
        ),
      );

    return Path.combine(PathOperation.union, vertical, horizontal);
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => oldDelegate.color != color;
}

/// The mark on its brand tile — the app icon, and the lockup on the launch
/// screens.
///
/// A squircle rather than a circle: it is the shape the icon is masked to on
/// both platforms, so the badge in the app and the icon on the home screen are
/// recognisably the same object.
class AppLogoTile extends StatelessWidget {
  const AppLogoTile({super.key, required this.size, this.radiusFactor = 0.24});

  final double size;

  /// Corner radius as a fraction of [size]. The default matches the mask iOS
  /// applies and Android's adaptive shape.
  final double radiusFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColors.brandSweep,
        borderRadius: BorderRadius.circular(size * radiusFactor),
      ),
      // The mark sits in the middle ~58%, which keeps it clear of the corner
      // mask on a circular launcher and of a notification tray's crop.
      child: AppLogoMark(size: size * 0.58, color: AppColors.onBrand),
    );
  }
}
