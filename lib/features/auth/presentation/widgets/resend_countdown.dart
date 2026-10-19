import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';

/// "Resend OTP in 00:28" while the cooldown runs, then a tappable
/// "Resend OTP" once it expires.
class ResendCountdown extends StatelessWidget {
  const ResendCountdown({
    super.key,
    required this.countdown,
    required this.canResend,
    required this.isResending,
    required this.onResend,
  });

  final String countdown;
  final bool canResend;
  final bool isResending;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final text = sizing.text;

    if (isResending) {
      return Center(
        child: Text(tr('Sending a new code…'), style: text.countdownLabel),
      );
    }

    if (canResend) {
      return Center(
        child: TextButton(
          onPressed: onResend,
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(
              horizontal: sizing.spacingSm,
              vertical: sizing.spacingXxs,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(tr('Resend OTP'), style: text.countdownValue),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(tr('Resend OTP in'), style: text.countdownLabel),
        SizedBox(width: sizing.spacingXxs),
        Text(countdown, style: text.countdownValue),
      ],
    );
  }
}
