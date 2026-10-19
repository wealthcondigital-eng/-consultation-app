import 'package:consultation_app/features/home/presentation/widgets/waving_hand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({bool reduceMotion = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: WavingHand()),
    ),
  );
}

Transform _transform(WidgetTester tester) =>
    tester.widget<Transform>(find.byType(Transform));

/// `sin(angle)` from the rotation matrix — sign and magnitude are all this
/// needs, and at these angles it tracks the radians closely.
double _rock(WidgetTester tester) => _transform(tester).transform.storage[1];

/// Samples the rock across the whole animation.
Future<List<double>> _sample(WidgetTester tester) async {
  final samples = <double>[];

  for (var elapsed = 0; elapsed <= 1100; elapsed += 25) {
    samples.add(_rock(tester));
    await tester.pump(const Duration(milliseconds: 25));
  }
  return samples;
}

void main() {
  group('WavingHand', () {
    testWidgets('rocks to both sides, evenly, then rests', (tester) async {
      await tester.pumpWidget(_host());
      final samples = await _sample(tester);

      final left = samples.reduce((a, b) => a < b ? a : b);
      final right = samples.reduce((a, b) => a > b ? a : b);

      // A wave goes both ways. Pivoting or tweening wrongly tends to produce a
      // one-sided flap, which this catches.
      expect(right, greaterThan(0.2));
      expect(left, lessThan(-0.2));

      // And it is symmetric — a hand running out of energy is not a greeting.
      expect((right + left).abs(), lessThan(0.06));

      // It must finish on its own: a looping wave never lets the tree settle,
      // which would hang `pumpAndSettle` wherever the home screen is rendered.
      await tester.pumpAndSettle();
      expect(_rock(tester), closeTo(0, 0.001));
    });

    testWidgets('pivots at the wrist, not the centre', (tester) async {
      await tester.pumpWidget(_host());
      await tester.pump(const Duration(milliseconds: 90));

      // Rotating about a corner or the middle translates the glyph as it turns;
      // about bottom-centre it only turns.
      expect(_transform(tester).alignment, Alignment.bottomCenter);
    });

    testWidgets('stays still when the system asks for reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(_host(reduceMotion: true));

      await tester.pump(const Duration(milliseconds: 200));
      expect(_rock(tester), closeTo(0, 0.001));
    });

    testWidgets('is decorative, so it adds nothing for screen readers', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();

      expect(find.byType(ExcludeSemantics), findsOneWidget);
      handle.dispose();
    });
  });
}
