import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../responsive/app_sizing.dart';
import '../l10n/tr.dart';

/// "Version 1.0.0 (1)" — read from the installed build, not hard-coded, so it
/// always matches what Play shows and what a support request needs to quote.
///
/// Comes from `version:` in `pubspec.yaml` (or `--build-name` /
/// `--build-number`), so bumping the release is the only edit it ever needs.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  static final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return FutureBuilder<PackageInfo>(
      future: _info,
      builder: (context, snapshot) {
        final info = snapshot.data;
        // Same height before and after it resolves, so nothing below it jumps.
        final text = info == null
            ? ''
            : tr('Version {version} ({build})', {
                'version': info.version,
                'build': info.buildNumber,
              });
        return Text(
          text,
          textAlign: TextAlign.center,
          style: sizing.text.fieldCaption,
        );
      },
    );
  }
}
