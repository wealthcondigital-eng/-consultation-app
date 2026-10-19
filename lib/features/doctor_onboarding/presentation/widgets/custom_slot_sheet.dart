import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../domain/entities/doctor_availability.dart';
import '../../../../core/l10n/tr.dart';

/// Picks a window the presets do not offer.
///
/// A sheet rather than a permanent block on the availability screen: two
/// dropdowns and a button sat below the fold for every doctor who was happy
/// with the hourly presets, which is most of them.
class CustomSlotSheet extends StatefulWidget {
  const CustomSlotSheet({super.key, required this.times});

  /// The marks a window may start or end on.
  final List<ClockTime> times;

  /// Returns the chosen window, or null when dismissed.
  static Future<AvailabilitySlot?> show(
    BuildContext context, {
    required List<ClockTime> times,
  }) {
    return showModalBottomSheet<AvailabilitySlot>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizing.radiusLg),
        ),
      ),
      builder: (_) => CustomSlotSheet(times: times),
    );
  }

  @override
  State<CustomSlotSheet> createState() => _CustomSlotSheetState();
}

class _CustomSlotSheetState extends State<CustomSlotSheet> {
  ClockTime _from = const ClockTime(hour: 8, minute: 0);
  ClockTime _to = const ClockTime(hour: 9, minute: 0);

  AvailabilitySlot get _slot => AvailabilitySlot(start: _from, end: _to);

  /// Only the marks after the start: an end time before it is not a window the
  /// doctor should be able to pick in the first place.
  List<ClockTime> get _endTimes =>
      widget.times.where((time) => time.compareTo(_from) > 0).toList();

  void _setFrom(ClockTime time) {
    setState(() {
      _from = time;
      // Keep the window pointing forwards.
      if (_to.compareTo(time) <= 0) {
        _to = _endTimes.isEmpty ? time : _endTimes.first;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        0,
        sizing.screenPaddingH,
        // Clears the home indicator and the keyboard, if one ever opens here.
        sizing.spacingLg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Add a time slot'), style: sizing.text.cardTitleLarge),
          SizedBox(height: sizing.spacingXxs),
          Text(
            tr('Patients can book any window you list here.'),
            style: sizing.text.helperText,
          ),
          SizedBox(height: sizing.spacingLg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AppDropdownField<ClockTime>(
                  label: 'FROM',
                  hint: 'Start',
                  value: _from,
                  items: widget.times,
                  labelOf: (time) => time.paddedLabel,
                  onChanged: (time) {
                    if (time != null) _setFrom(time);
                  },
                ),
              ),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: AppDropdownField<ClockTime>(
                  label: 'TO',
                  hint: 'End',
                  value: _endTimes.contains(_to) ? _to : null,
                  items: _endTimes,
                  labelOf: (time) => time.paddedLabel,
                  onChanged: (time) {
                    if (time != null) setState(() => _to = time);
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: sizing.spacingLg),
          AppButton.primary(
            label: tr('Add {slot}', {'slot': _slot.label}),
            onPressed: _slot.isValid
                ? () => Navigator.of(context).pop(_slot)
                : null,
          ),
        ],
      ),
    );
  }
}
