import 'dart:ui';

import 'package:consultation_app/core/responsive/app_breakpoints.dart';
import 'package:consultation_app/core/responsive/app_sizing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSizing', () {
    test('renders design values 1:1 on the design frame', () {
      final sizing = AppSizing.fromSize(AppBreakpoints.designSize);

      expect(sizing.widthScale, closeTo(1, 0.001));
      expect(sizing.heightScale, closeTo(1, 0.001));
      expect(sizing.buttonHeight, closeTo(48, 0.001));
      expect(sizing.brandBadgeSize, closeTo(220, 0.001));
      expect(sizing.text.brandTitle.fontSize, closeTo(36, 0.001));
    });

    test('scales down on a small phone but never past the floor', () {
      // iPhone SE (1st gen) — the smallest screen worth supporting.
      final sizing = AppSizing.fromSize(const Size(320, 568));

      expect(sizing.widthScale, lessThan(1));
      expect(
        sizing.widthScale,
        greaterThanOrEqualTo(AppBreakpoints.minWidthScale),
      );
      expect(
        sizing.text.brandTitle.fontSize,
        greaterThanOrEqualTo(36 * AppBreakpoints.minTextScale),
      );
    });

    test('caps scaling on a tablet so controls stay phone-sized', () {
      final sizing = AppSizing.fromSize(const Size(1024, 1366));

      expect(sizing.deviceType, DeviceType.expanded);
      expect(
        sizing.widthScale,
        lessThanOrEqualTo(AppBreakpoints.maxWidthScale),
      );
      expect(sizing.buttonHeight, lessThan(60));
    });

    test('classifies window size', () {
      expect(
        AppSizing.fromSize(const Size(402, 874)).deviceType,
        DeviceType.compact,
      );
      expect(
        AppSizing.fromSize(const Size(700, 1000)).deviceType,
        DeviceType.medium,
      );
      expect(
        AppSizing.fromSize(const Size(900, 1200)).deviceType,
        DeviceType.expanded,
      );
    });
  });
}
