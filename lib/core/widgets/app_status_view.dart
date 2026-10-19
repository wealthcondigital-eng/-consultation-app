import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// A screen with nothing on it yet, said plainly.
///
/// Shared because the app now has a dozen lists — appointments, patients,
/// earnings, documents — and each was growing its own centred icon, its own
/// message and its own slightly different spacing. One widget means an empty
/// list looks the same wherever it appears, which is what makes it read as a
/// state rather than as a fault.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;

  /// One line under the title. Optional — a title alone is enough when there
  /// is nothing useful to add.
  final String? message;

  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final message = this.message;
    final actionLabel = this.actionLabel;
    final onAction = this.onAction;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: sizing.screenPaddingH,
          vertical: sizing.spacingXl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: sizing.iconChipSize,
              height: sizing.iconChipSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: sizing.iconMd,
                color: AppColors.textTertiary,
              ),
            ),
            SizedBox(height: sizing.spacingMd),
            Text(
              tr(title),
              style: sizing.text.cardTitleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              SizedBox(height: sizing.spacingXs),
              Text(
                tr(message),
                style: sizing.text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: sizing.spacingMd),
              TextButton(
                onPressed: onAction,
                child: Text(tr(actionLabel), style: sizing.text.sectionAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A read that failed, with a way to try again.
///
/// Distinct from [AppEmptyState] on purpose: "nothing here" and "we could not
/// find out" are different facts, and a retry button on the first one invites
/// someone to keep tapping at a list that is genuinely empty.
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Center(
      child: Padding(
        padding: sizing.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: sizing.r(40), color: AppColors.textTertiary),
            SizedBox(height: sizing.spacingSm),
            Text(
              tr(message),
              style: sizing.text.bodySmall,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: sizing.spacingXs),
            TextButton(
              onPressed: onRetry,
              child: Text(tr('Retry'), style: sizing.text.sectionAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// An inline error above a list that still has content, with a retry.
///
/// For the case where a refresh failed but the previous rows are still worth
/// showing — taking the whole screen away because the newest read failed is
/// how a list that loaded fine ten seconds ago becomes an error page.
class AppInlineError extends StatelessWidget {
  const AppInlineError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.only(bottom: sizing.spacingSm),
      child: Row(
        children: [
          Expanded(child: Text(tr(message), style: sizing.text.error)),
          TextButton(
            onPressed: onRetry,
            child: Text(tr('Retry'), style: sizing.text.sectionAction),
          ),
        ],
      ),
    );
  }
}
