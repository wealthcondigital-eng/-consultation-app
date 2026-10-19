import 'package:consultation_app/core/push/push_service.dart';
import 'package:consultation_app/core/push/ring_readiness_probe.dart';
import 'package:consultation_app/core/session/session_store.dart';
import 'package:consultation_app/features/home/presentation/controllers/ring_readiness_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone whose settings a test decides.
class FakeRingProbe implements RingReadinessProbe {
  FakeRingProbe({Set<RingCheckKind>? applicable, Set<RingCheckKind>? satisfied})
    : applicable = applicable ?? RingCheckKind.values.toSet(),
      satisfied = satisfied ?? {};

  final Set<RingCheckKind> applicable;
  final Set<RingCheckKind> satisfied;
  final List<RingCheckKind> fixed = [];

  /// What a fix changes on the phone, applied when [fix] is called. The
  /// permission dialogs answer at once; a settings screen does not.
  final Set<RingCheckKind> grantsOnFix = {};

  @override
  Future<bool> applies(RingCheckKind kind) async => applicable.contains(kind);

  @override
  Future<bool> isSatisfied(RingCheckKind kind) async =>
      satisfied.contains(kind);

  @override
  Future<void> fix(RingCheckKind kind) async {
    fixed.add(kind);
    if (grantsOnFix.contains(kind)) satisfied.add(kind);
  }

  @override
  Future<void> confirmAutostart() async =>
      satisfied.add(RingCheckKind.autostart);
}

void main() {
  test('is not ready before it has looked', () {
    final controller = RingReadinessController(FakeRingProbe());

    expect(controller.hasLoaded, isFalse);
    expect(controller.isReady, isFalse);
  });

  test('lists only what applies to this phone, and what is missing', () async {
    final controller = RingReadinessController(
      FakeRingProbe(
        // A Samsung: no auto-start list to be on.
        applicable: {
          RingCheckKind.notifications,
          RingCheckKind.fullScreen,
          RingCheckKind.battery,
        },
        satisfied: {RingCheckKind.notifications},
      ),
    );

    await controller.refresh();

    expect(controller.checks.map((check) => check.kind), [
      RingCheckKind.notifications,
      RingCheckKind.fullScreen,
      RingCheckKind.battery,
    ]);
    expect(controller.missing.map((check) => check.kind), [
      RingCheckKind.fullScreen,
      RingCheckKind.battery,
    ]);
    expect(controller.isReady, isFalse);
  });

  test('is ready when everything that applies is met', () async {
    final controller = RingReadinessController(
      FakeRingProbe(
        applicable: {RingCheckKind.notifications, RingCheckKind.battery},
        satisfied: {RingCheckKind.notifications, RingCheckKind.battery},
      ),
    );

    await controller.refresh();

    expect(controller.isReady, isTrue);
  });

  test('a permission dialog is re-read as soon as it closes', () async {
    final probe = FakeRingProbe(applicable: {RingCheckKind.fullScreen})
      ..grantsOnFix.add(RingCheckKind.fullScreen);
    final controller = RingReadinessController(probe);
    await controller.refresh();

    await controller.fix(RingCheckKind.fullScreen);

    expect(probe.fixed, [RingCheckKind.fullScreen]);
    expect(controller.isReady, isTrue);
  });

  test('a settings screen is re-read when the doctor comes back', () async {
    final probe = FakeRingProbe(applicable: {RingCheckKind.battery});
    final controller = RingReadinessController(probe);
    await controller.refresh();

    await controller.fix(RingCheckKind.battery);
    expect(probe.fixed, [RingCheckKind.battery]);
    expect(controller.isReady, isFalse);

    // The doctor changed it in Settings and returned to the app.
    probe.satisfied.add(RingCheckKind.battery);
    await controller.refresh();

    expect(controller.isReady, isTrue);
  });

  test('auto-start is taken on the doctor’s word', () async {
    final controller = RingReadinessController(
      FakeRingProbe(applicable: {RingCheckKind.autostart}),
    );
    await controller.refresh();
    expect(controller.isReady, isFalse);

    await controller.confirmAutostart();

    expect(controller.isReady, isTrue);
  });

  test('every check says what to do about it', () {
    for (final kind in RingCheckKind.values) {
      final check = RingCheck(kind: kind, isSatisfied: false);

      expect(check.title, isNotEmpty);
      expect(check.description, isNotEmpty);
      expect(check.actionLabel, isNotEmpty);
    }
  });

  group('a phone nobody is signed in on', () {
    test('is not rung', () async {
      expect(await hasStoredSession(store: InMemorySessionStore()), isFalse);
    });

    test('a signed-in phone is', () async {
      final store = InMemorySessionStore();
      await store.write({'token': 'jwt-abc'});

      expect(await hasStoredSession(store: store), isTrue);
    });
  });
}
