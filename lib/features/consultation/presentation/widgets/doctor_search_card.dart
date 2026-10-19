import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/doctor_search_session.dart';

/// A doctor search running in the background, reported on the dashboard.
///
/// The half of `DoctorSearchSession` the patient can see. Backing out of the
/// search screen used to throw the search away silently; now it keeps running
/// and this is where it surfaces — "Finding a doctor" while it works, then
/// "3 doctors found", and a tap opens them.
///
/// Three states and they read differently. Searching is something happening, so
/// it spins. A result is something to act on, so the whole card is tappable and
/// says so. Nobody found and a failed search are dead ends, so they offer Try
/// again rather than a tap that leads to an empty list.
class DoctorSearchCard extends StatelessWidget {
  const DoctorSearchCard({
    super.key,
    required this.session,
    required this.onOpen,
    required this.onDismiss,
    required this.onRetry,
  });

  final DoctorSearchSession session;

  /// Opens the listing the search filled. Only wired while there is one.
  final VoidCallback onOpen;

  /// Clears the search. The card is the only thing holding it, so dismissing it
  /// is what ends it.
  final VoidCallback onDismiss;

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final isSearching = session.isSearching;
    final hasResults = session.hasResults;
    final failed = session.phase == DoctorSearchPhase.failed;

    final accent = hasResults
        ? AppColors.successStrong
        : failed
        ? AppColors.danger
        : AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        // Only when there is somewhere to go. A card that looks tappable and
        // does nothing is worse than one that plainly does not.
        onTap: hasResults ? onOpen : null,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        child: Ink(
          padding: EdgeInsets.all(sizing.cardPadding),
          decoration: BoxDecoration(
            color: hasResults
                ? AppColors.badgeSurface
                : AppColors.primarySurface,
            borderRadius: BorderRadius.circular(sizing.radiusLg),
            border: Border.all(width: sizing.hairline, color: accent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: sizing.iconChipSize * 0.75,
                    height: sizing.iconChipSize * 0.75,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: isSearching
                        // A spinner rather than a glyph while it is working:
                        // the card is reporting something that is happening,
                        // and a static icon reads as stuck.
                        ? SizedBox.square(
                            dimension: sizing.iconSm,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Icon(
                            switch (session.phase) {
                              DoctorSearchPhase.found => Icons.groups_2_rounded,
                              DoctorSearchPhase.empty =>
                                Icons.person_search_rounded,
                              _ => Icons.error_outline_rounded,
                            },
                            size: sizing.iconSm,
                            color: Colors.white,
                          ),
                  ),
                  SizedBox(width: sizing.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.headline,
                          style: sizing.text.cardTitle.copyWith(
                            color: hasResults
                                ? AppColors.success
                                : AppColors.primaryDeep,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: sizing.spacingXxs / 2),
                        Text(
                          session.detail,
                          style: sizing.text.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Dismissing is always available. The search belongs to the
                  // patient, and one they have stopped caring about should not
                  // need a decision to get rid of.
                  IconButton(
                    onPressed: onDismiss,
                    tooltip: isSearching ? tr('Stop looking') : tr('Dismiss'),
                    iconSize: sizing.iconSm,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              // Cancel, spelled out, while the search is running. The ✕ above
              // does the same thing and always did — but it is a 20pt glyph in
              // a corner, and a patient watching a spinner that will not stop
              // does not read that as the way out. The one state that most
              // needs an exit was the only one with no button in it.
              if (isSearching) ...[
                SizedBox(height: sizing.spacingSm),
                SizedBox(
                  height: sizing.buttonHeightCompact,
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(sizing.radiusMd),
                      ),
                    ),
                    child: Text(
                      tr('Cancel search'),
                      style: sizing.text.buttonLabelCompact,
                    ),
                  ),
                ),
              ],
              if (hasResults ||
                  session.phase != DoctorSearchPhase.searching) ...[
                SizedBox(height: sizing.spacingSm),
                SizedBox(
                  height: sizing.buttonHeightCompact,
                  child: ElevatedButton(
                    onPressed: hasResults ? onOpen : onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(sizing.radiusMd),
                      ),
                    ),
                    child: Text(
                      hasResults ? tr('See doctors') : tr('Try again'),
                      style: sizing.text.buttonLabelCompact,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
