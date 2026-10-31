import 'package:consultation_app/core/update/app_update_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Play's answer to `check`, as the Android bridge would give it.
void _playOffers(int versionCode) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('consult/app_update'),
    (call) async => call.method == 'check'
        ? {
            'available': true,
            'priority': 0,
            'availableVersionCode': versionCode,
            'downloaded': false,
          }
        : null,
  );
  messenger.setMockStreamHandler(
    const EventChannel('consult/app_update/events'),
    MockStreamHandler.inline(onListen: (_, _) {}),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('names the version and its notes when they match Play', () async {
    _playOffers(18);
    final controller = AppUpdateController(
      supported: true,
      latestRelease: () async => {
        'release': {
          'versionCode': 18,
          'versionName': '1.0.18',
          'releaseNotes': '• Faster booking\n\n- New colours',
        },
      },
    );

    await controller.check();

    expect(controller.phase, AppUpdatePhase.available);
    expect(controller.versionName, '1.0.18');
    expect(controller.releaseNotes, ['Faster booking', 'New colours']);
  });

  test('ignores notes written for a different build', () async {
    _playOffers(18);
    final controller = AppUpdateController(
      supported: true,
      latestRelease: () async => {
        'release': {
          'versionCode': 17,
          'versionName': '1.0.17',
          'releaseNotes': 'Old notes',
        },
      },
    );

    await controller.check();

    expect(controller.versionName, isNull);
    expect(controller.releaseNotes, isEmpty);
  });

  test('offers once per version, and again after an update notification', () async {
    _playOffers(18);
    final controller = AppUpdateController(supported: true);

    await controller.check();
    expect(controller.claimPrompt(), isTrue);
    expect(controller.claimPrompt(), isFalse);

    controller.dismiss();
    expect(controller.isDismissed, isTrue);

    // Coming back to the app moments later asks nobody anything.
    await controller.recheck();
    expect(controller.claimPrompt(), isFalse);

    // A "new version" notification forces it, and Later no longer holds.
    await controller.recheck(force: true);
    expect(controller.isDismissed, isFalse);
    expect(controller.claimPrompt(), isTrue);
  });

  test('a newer build gets its own offer in the same session', () async {
    _playOffers(18);
    final controller = AppUpdateController(supported: true);

    await controller.check();
    expect(controller.claimPrompt(), isTrue);

    _playOffers(19);
    await controller.recheck(force: true);
    expect(controller.claimPrompt(), isTrue);
  });
}
