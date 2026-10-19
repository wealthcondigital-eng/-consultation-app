import 'package:flutter/material.dart';

import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import '../l10n/tr.dart';

/// A labelled switch inside a settings card.
///
/// Shared by the patient's and the doctor's settings screens, which have the
/// same job and used to be on their way to two copies of it. The whole row is
/// the tap target, not just the switch — a 32pt toggle at the far edge of a
/// phone is a miss waiting to happen.
class AppSwitchRow extends StatelessWidget {
  const AppSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.isBusy = false,
    this.isCritical = false,
    this.showDivider = true,
  });

  final String label;
  final bool value;

  /// Null disables the row — used while another switch on the screen is in
  /// flight, so two writes cannot race.
  final ValueChanged<bool>? onChanged;

  /// One or two lines under the label, saying what the switch actually does.
  final String? description;

  /// True while this row's write is in flight. The switch is replaced by a
  /// spinner rather than left tappable mid-request.
  final bool isBusy;

  /// Marks a switch whose off state stops the person working — the doctor's
  /// incoming consultations. Tinted when off, so a setting turned off by
  /// accident does not look like the platform having gone quiet.
  final bool isCritical;

  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final description = this.description;
    final onChanged = this.onChanged;
    final warns = isCritical && !value;

    return Column(
      children: [
        InkWell(
          onTap: onChanged == null || isBusy ? null : () => onChanged(!value),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sizing.cardPadding,
              vertical: sizing.spacingSm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(label),
                        style: sizing.text.fieldValue.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (description != null) ...[
                        SizedBox(height: sizing.spacingXxs / 2),
                        Text(
                          tr(description),
                          style: sizing.text.metaLabel.copyWith(
                            color: warns
                                ? AppColors.danger
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: sizing.spacingSm),
                if (isBusy)
                  SizedBox.square(
                    dimension: sizing.iconSm,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    value: value,
                    onChanged: onChanged,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.only(left: sizing.cardPadding),
            child: Container(
              height: sizing.hairline,
              color: AppColors.dividerFaint,
            ),
          ),
      ],
    );
  }
}
