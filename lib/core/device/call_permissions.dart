import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../logging/auth_logger.dart';
import '../widgets/app_confirm_dialog.dart';

/// The microphone, and the camera on a video call, asked for before a call
/// starts rather than in the middle of one.
///
/// Leaving it to WebRTC meant the system prompt arrived after the call screen
/// had already started the call's foreground service — which Android refuses
/// to run with a microphone it has not been granted, and answered by closing
/// the app. A doctor answering their first call from the lock screen hit
/// exactly that. Asked here, the call screen only ever opens a microphone it
/// is allowed to use.
class CallPermissions {
  const CallPermissions._();

  /// Android only. Everywhere else WebRTC's own prompt is the right one.
  static bool get _applies =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static List<Permission> _needed({required bool video}) => [
    Permission.microphone,
    if (video) Permission.camera,
  ];

  /// True when everything the call needs is already granted. Asks nothing.
  static Future<bool> granted({required bool video}) async {
    if (!_applies) return true;

    try {
      for (final permission in _needed(video: video)) {
        if (!await permission.isGranted) return false;
      }
      return true;
    } catch (error) {
      AuthLogger.event('PERMISSION · could not check', {'reason': '$error'});
      // Unknown is not a refusal. WebRTC asks again if it has to.
      return true;
    }
  }

  /// Asks for whatever the call is missing, explaining first and pointing to
  /// Settings when the phone will no longer ask. True once it is all granted.
  static Future<bool> ensure(
    BuildContext context, {
    required bool video,
  }) async {
    if (!_applies) return true;
    if (await granted(video: video)) return true;

    try {
      final statuses = await _needed(video: video).request();
      if (statuses.values.every((s) => s.isGranted)) return true;

      if (!context.mounted) return false;

      // "Don't ask again", or refused twice: Android will not show its prompt
      // again, so the only way left is the app's own settings page.
      final blocked = statuses.values.any((s) => s.isPermanentlyDenied);

      // Whole sentences, one per case, so each is a key the Hindi table can
      // translate — the dialog passes them through `tr()`.
      final open = await AppConfirmDialog.show(
        context,
        title: video ? 'Allow camera and microphone' : 'Allow microphone',
        message: switch ((video, blocked)) {
          (true, true) =>
            'Consultations need your camera and microphone. Open Settings, '
                'tap Permissions, and allow both for this app.',
          (false, true) =>
            'Consultations need your microphone. Open Settings, tap '
                'Permissions, and allow it for this app.',
          (true, false) =>
            'Consultations need your camera and microphone so the other '
                'person can see and hear you.',
          (false, false) =>
            'Consultations need your microphone so the other person can '
                'hear you.',
        },
        confirmLabel: blocked ? 'Open Settings' : 'Allow',
        cancelLabel: 'Not now',
        icon: video ? Icons.videocam_rounded : Icons.mic_rounded,
      );
      if (!open) return false;

      if (blocked) {
        await openAppSettings();
        // Coming back from Settings is the only signal there is.
        return granted(video: video);
      }

      final again = await _needed(video: video).request();
      return again.values.every((s) => s.isGranted);
    } catch (error) {
      AuthLogger.event('PERMISSION · could not ask', {'reason': '$error'});
      return granted(video: video);
    }
  }

  /// Asks once, quietly, ahead of the first call — for a doctor going Online,
  /// who could be rung at any moment. No explanation and no Settings detour:
  /// the call screen does that properly if it is still missing then.
  static Future<void> warmUp() async {
    if (!_applies) return;

    try {
      final missing = <Permission>[
        for (final permission in _needed(video: true))
          if (await permission.isDenied) permission,
      ];
      if (missing.isNotEmpty) await missing.request();
    } catch (error) {
      AuthLogger.event('PERMISSION · could not ask', {'reason': '$error'});
    }
  }
}
