import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// What a message is telling the user, which is what decides its colour and
/// its glyph.
enum AppSnackKind {
  /// Something worked. Green, and short — a confirmation nobody has to read
  /// twice.
  success,

  /// Something failed. Red, and held longer, because a failure usually names
  /// an action to take.
  error,

  /// Neutral. Used for progress and for state that is neither good nor bad —
  /// "your request was withdrawn", say.
  info,

  /// Something the user should know before it bites. Amber.
  warning,
}

/// Every message the app shows, in one shape.
///
/// Before this, snackbars were built at each call site — a bare
/// `SnackBar(content: Text(message))` in some places, a six-second one in
/// others, and nothing to tell a success from a failure but the wording. The
/// result was that the most important messages in the app (a call that could
/// not connect, a payment that did not go through) looked exactly like the
/// least important.
///
/// Three things this fixes, and they are the reason to keep going through it:
///
///  * **Colour carries the outcome.** A red bar is a failure before a word of
///    it has been read, which matters most for the people who will not read it.
///  * **Duration follows the kind.** A failure names something to do about it
///    and stays up long enough to be acted on; a confirmation gets out of the
///    way.
///  * **One bar at a time.** Every entry point hides the current bar first, so
///    a screen that reports twice in quick succession replaces its message
///    rather than queueing a second one behind it.
class AppSnackBar {
  const AppSnackBar._();

  static void success(
    BuildContext context,
    String message, {
    String? action,
    VoidCallback? onAction,
  }) => _show(context, message, AppSnackKind.success, action, onAction);

  static void error(
    BuildContext context,
    String message, {
    String? action,
    VoidCallback? onAction,
  }) => _show(context, message, AppSnackKind.error, action, onAction);

  static void info(
    BuildContext context,
    String message, {
    String? action,
    VoidCallback? onAction,
  }) => _show(context, message, AppSnackKind.info, action, onAction);

  static void warning(
    BuildContext context,
    String message, {
    String? action,
    VoidCallback? onAction,
  }) => _show(context, message, AppSnackKind.warning, action, onAction);

  /// Clears whatever is showing. For a screen that is about to navigate away
  /// and whose message would otherwise follow it.
  static void dismiss(BuildContext context) =>
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();

  static void _show(
    BuildContext context,
    String message,
    AppSnackKind kind,
    String? action,
    VoidCallback? onAction,
  ) {
    // `maybeOf`: a controller can report an error as its screen is being torn
    // down, and a missing messenger is not worth an exception on the way out.
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null || message.trim().isEmpty) return;

    final sizing = context.sizing;
    final (background, icon) = _styleOf(kind);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, size: sizing.iconSm, color: Colors.white),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: Text(
                  tr(message),
                  style: sizing.text.cardTitle.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  // Four lines is enough for the longest message the API
                  // sends; past that it is a paragraph and belongs on a
                  // screen, not over one.
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          elevation: 6,
          duration: _durationOf(kind),
          margin: EdgeInsets.fromLTRB(
            sizing.screenPaddingH * 0.66,
            0,
            sizing.screenPaddingH * 0.66,
            sizing.spacingMd,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: sizing.spacingMd,
            vertical: sizing.spacingSm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(sizing.radiusLg),
          ),
          action: action == null || onAction == null
              ? null
              : SnackBarAction(
                  label: tr(action),
                  textColor: Colors.white,
                  onPressed: onAction,
                ),
        ),
      );
  }

  /// Failures get six seconds because they usually name something to do; the
  /// rest get three, which is long enough to read one line.
  static Duration _durationOf(AppSnackKind kind) => switch (kind) {
    AppSnackKind.error => const Duration(seconds: 6),
    AppSnackKind.warning => const Duration(seconds: 5),
    AppSnackKind.success => const Duration(seconds: 3),
    AppSnackKind.info => const Duration(seconds: 4),
  };

  /// Darker than the palette's own status colours: these are backgrounds for
  /// white text, and `AppColors.success` is tuned for text on a tint.
  static (Color, IconData) _styleOf(AppSnackKind kind) => switch (kind) {
    AppSnackKind.success => (
      const Color(0xFF047857),
      Icons.check_circle_rounded,
    ),
    AppSnackKind.error => (const Color(0xFFB91C1C), Icons.error_rounded),
    AppSnackKind.warning => (const Color(0xFFB45309), Icons.warning_rounded),
    AppSnackKind.info => (AppColors.primaryDeep, Icons.info_rounded),
  };
}
