import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/doctor_availability.dart';
import '../controllers/availability_controller.dart';
import '../widgets/availability_day_row.dart';
import '../widgets/availability_slot_picker.dart';
import '../widgets/custom_slot_sheet.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/l10n/tr.dart';

/// Which of the two ways this screen was reached.
///
/// Reached twice: as the last step of the post-approval wizard, and from the
/// doctor's profile afterwards. Where Save goes depends on which, and the
/// screen used to decide by asking `navigator.canPop()` — which is **true in
/// both cases**, because the wizard pushes this on top of the fee screen. So
/// the last step of onboarding saved the schedule and then popped back to the
/// fee screen: the write had gone through, the doctor was returned to the
/// screen before, and it read as a save that had not worked.
class SetAvailabilityArgs {
  const SetAvailabilityArgs({this.isWizardStep = false});

  /// True when this is the wizard's last step, so saving hands over to the
  /// doctor's home screen and clears the onboarding stack behind it.
  final bool isWizardStep;
}

/// When the doctor consults: the days, the windows, and whether they are on
/// right now.
///
/// Two questions, one card each, and the save fixed to the bottom — it used to
/// be the third thing below a fold that also held a permanent custom-time form.
class SetAvailabilityScreen extends StatefulWidget {
  const SetAvailabilityScreen({
    super.key,
    this.args = const SetAvailabilityArgs(),
  });

  final SetAvailabilityArgs args;

  @override
  State<SetAvailabilityScreen> createState() => _SetAvailabilityScreenState();
}

class _SetAvailabilityScreenState extends State<SetAvailabilityScreen> {
  late final AvailabilityController _controller = sl<AvailabilityController>();

  /// The half-hour marks a custom window can start or end on.
  ///
  /// The whole day, ending at the midnight that closes it. It used to run 6am
  /// to 10pm, which quietly ruled out every doctor who takes calls overnight —
  /// and a night shift is exactly the schedule the presets do not cover, so the
  /// one control meant to handle the unusual case could not.
  static final List<ClockTime> _customTimes = [
    for (var hour = 0; hour < 24; hour++)
      for (final minute in [0, 30]) ClockTime(hour: hour, minute: minute),
    ClockTime.endOfDay,
  ];

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onChanged)
      ..load();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    final message = _controller.errorMessage;
    if (message == null || !mounted) return;

    _controller.acknowledgeError();
    AppSnackBar.error(context, message);
  }

  Future<void> _addCustomSlot() async {
    final slot = await CustomSlotSheet.show(context, times: _customTimes);
    if (slot == null) return;

    _controller.addCustomSlot(slot);
  }

  Future<void> _save() async {
    final saved = await _controller.save();
    if (!saved || !mounted) return;

    final navigator = Navigator.of(context);

    // The wizard's last step hands over to the app itself, clearing the
    // onboarding stack. Decided from the argument, not from
    // `navigator.canPop()` — which is true here either way, because the wizard
    // pushes this screen on top of the fee screen, so the check sent a doctor
    // finishing onboarding back to the fee screen instead of home.
    //
    // `canPop` still has a job, just not that one: it answers whether popping
    // is *possible*. Opened as the app's first route — which is what a
    // deep link or a restart into this screen looks like — there is nothing
    // behind it, and a pop would close the app rather than go anywhere.
    if (widget.args.isWizardStep || !navigator.canPop()) {
      AppSnackBar.success(context, 'Your availability is set.');

      await navigator.pushNamedAndRemoveUntil(
        AppRoutes.doctorHome,
        (route) => false,
      );
      return;
    }

    // Opened from the profile, this is a screen to come back from. It hands the
    // stored schedule back so the row that opened it shows the new summary
    // without a second read, and says so — a screen that closes silently is
    // indistinguishable from one that failed.
    AppSnackBar.success(context, 'Availability saved.');

    navigator.pop(_controller.availability);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        scrollable: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.isInitialLoad) {
              return const Center(child: CircularProgressIndicator());
            }

            final availability = _controller.availability;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTopBar(
                  title: 'Set Availability',
                  variant: AppTopBarVariant.outlined,
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      sizing.screenPaddingH,
                      sizing.spacingXs,
                      sizing.screenPaddingH,
                      sizing.spacingLg,
                    ),
                    children: [
                      _OnlineStatusCard(
                        isOnline: availability.isOnline,
                        onChanged: _controller.toggleOnline,
                      ),
                      if (availability.isOnline &&
                          availability.validationError != null) ...[
                        SizedBox(height: sizing.spacingXs),
                        _OnlineNeedsHoursNote(
                          reason: availability.validationError!,
                        ),
                      ],
                      SizedBox(height: sizing.spacingXl),
                      _AroundTheClockCard(
                        isOn: availability.isAroundTheClock,
                        onChanged: _controller.setAroundTheClock,
                      ),
                      // Days and windows are what 24/7 *is*, so leaving them
                      // underneath would show the doctor a schedule they
                      // cannot touch without contradicting the switch they
                      // just set. Turning it off brings them back, empty.
                      if (!availability.isAroundTheClock) ...[
                        SizedBox(height: sizing.spacingXl),
                        _SectionHeading(
                          title: 'Select Days',
                          trailing: availability.days.isEmpty
                              ? null
                              : _daysLabel(availability),
                        ),
                        SizedBox(height: sizing.spacingXs),
                        _Card(
                          padding: EdgeInsets.symmetric(
                            horizontal: sizing.spacingSm,
                            vertical: sizing.cardPadding,
                          ),
                          child: AvailabilityDayRow(
                            selected: availability.days,
                            onToggle: _controller.toggleDay,
                            onSelectAll: _controller.selectDays,
                          ),
                        ),
                        SizedBox(height: sizing.spacingXl),
                        _SectionHeading(
                          title: 'Active Time Slots',
                          trailing: tr('{count} selected', {
                            'count': availability.slots.length,
                          }),
                        ),
                        SizedBox(height: sizing.spacingXs),
                        _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AvailabilitySlotPicker(
                                presets: _controller.presetSlots,
                                customSlots: _controller.customSlots,
                                selected: availability.slots,
                                onToggle: _controller.toggleSlot,
                                onRemoveCustom: _controller.removeCustomSlot,
                              ),
                              SizedBox(height: sizing.spacingMd),
                              Container(
                                height: sizing.hairline,
                                color: AppColors.dividerFaint,
                              ),
                              SizedBox(height: sizing.spacingXs),
                              _AddCustomTimeButton(onTap: _addCustomSlot),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _SaveBar(
                  availability: availability,
                  // The controller's, not the entity's: an empty schedule is
                  // only a problem for a doctor going *online*, and the bar
                  // used to print "Pick at least one day" at somebody who was
                  // deliberately clearing their hours.
                  problem: _controller.blockedReason,
                  isSaving: _controller.isSaving,
                  onSave: _controller.canSave ? _save : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// [DoctorAvailability.daysLabel], with the day names in the active language.
String _daysLabel(DoctorAvailability availability) {
  final label = availability.daysLabel;
  final count = availability.days.length;
  if (count == 0 || count == Weekday.values.length) return tr(label);

  // The English label is built from the short day names alone, so swapping
  // each one keeps the runs (`Mon-Fri`, `Mon, Wed`) exactly as collapsed.
  var localized = label;
  for (final day in Weekday.values) {
    localized = localized.replaceAll(day.shortLabel, tr(day.shortLabel));
  }
  return localized;
}

/// [DoctorAvailability.summaryLabel], in the active language.
String availabilitySummaryText(DoctorAvailability availability) {
  if (availability.isAroundTheClock) return tr('Available 24/7');
  if (!availability.isSaveable) return tr('Not set up yet');

  final count = availability.slots.length;
  final slots = tr(count == 1 ? '{count} slot' : '{count} slots', {
    'count': count,
  });
  return '${_daysLabel(availability)} · $slots';
}

/// The switch that decides whether patients can reach the doctor right now.
class _OnlineStatusCard extends StatelessWidget {
  const _OnlineStatusCard({required this.isOnline, required this.onChanged});

  final bool isOnline;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return _Card(
      child: Row(
        children: [
          Container(
            width: sizing.iconChipSize * 0.75,
            height: sizing.iconChipSize * 0.75,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isOnline
                  ? AppColors.successSurface
                  : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(sizing.radiusSm),
            ),
            child: Icon(
              isOnline
                  ? Icons.podcasts_rounded
                  : Icons.do_not_disturb_on_rounded,
              size: sizing.iconSm,
              color: isOnline ? AppColors.success : AppColors.textTertiary,
            ),
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Online Status'), style: sizing.text.cardTitle),
                SizedBox(height: sizing.spacingXxs),
                // Says what is true now rather than what the switch is for: a
                // doctor glancing at this wants to know whether the phone can
                // ring, not what a toggle does.
                Text(
                  tr(
                    isOnline
                        ? 'Patients can consult you right now'
                        : 'You will not receive instant consultations',
                  ),
                  style: sizing.text.cardSubtitle,
                ),
              ],
            ),
          ),
          SizedBox(width: sizing.spacingXs),
          Switch.adaptive(
            value: isOnline,
            activeTrackColor: AppColors.success,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// One switch for the doctor who is simply always available.
///
/// A round-the-clock practice is otherwise seven day chips and a hand-built
/// window per day: a lot of tapping to express "any time", and the result reads
/// as an elaborate schedule rather than as what it actually is.
class _AroundTheClockCard extends StatelessWidget {
  const _AroundTheClockCard({required this.isOn, required this.onChanged});

  final bool isOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return _Card(
      child: Row(
        children: [
          Container(
            width: sizing.iconChipSize * 0.75,
            height: sizing.iconChipSize * 0.75,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isOn ? AppColors.primarySurface : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(sizing.radiusSm),
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: sizing.iconSm,
              color: isOn ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Available 24/7'), style: sizing.text.cardTitle),
                SizedBox(height: sizing.spacingXxs),
                Text(
                  tr(
                    isOn
                        ? 'Every day, midnight to midnight'
                        : 'Or pick the days and hours you consult in',
                  ),
                  style: sizing.text.cardSubtitle,
                ),
              ],
            ),
          ),
          SizedBox(width: sizing.spacingXs),
          Switch.adaptive(value: isOn, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Says what "Online" needs, on the card that turned it on.
///
/// The Save button explains itself in the bar at the bottom, which is off
/// screen while the doctor is looking at the switch they just flipped. This
/// puts the reason where the cause is.
class _OnlineNeedsHoursNote extends StatelessWidget {
  const _OnlineNeedsHoursNote({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: sizing.iconXs,
            color: AppColors.textSecondary,
          ),
          SizedBox(width: sizing.spacingXs),
          Expanded(
            child: Text(
              tr(
                '{reason} Being online with no hours is a state a patient '
                'sees as bookable and finds nothing to book.',
                {'reason': tr(reason)},
              ),
              style: sizing.text.legalBody,
            ),
          ),
        ],
      ),
    );
  }
}

/// A heading with the state of the section on its right.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final trailing = this.trailing;

    return Row(
      children: [
        Expanded(child: Text(tr(title), style: sizing.text.fieldLabel)),
        if (trailing != null)
          Text(
            trailing,
            style: sizing.text.metaLabel.copyWith(
              color: AppColors.primaryVivid,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: padding ?? EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Opens the sheet that adds a window the presets do not cover.
class _AddCustomTimeButton extends StatelessWidget {
  const _AddCustomTimeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusSm);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: sizing.spacingXs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: sizing.iconXs,
                color: AppColors.primaryVivid,
              ),
              SizedBox(width: sizing.spacingXxs),
              Text(
                tr('Add Custom Time'),
                style: sizing.text.sectionAction.copyWith(
                  color: AppColors.primaryVivid,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The save, fixed to the bottom, over a line that says what is about to be
/// saved — or what is still missing.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.availability,
    required this.problem,
    required this.isSaving,
    required this.onSave,
  });

  final DoctorAvailability availability;

  /// Why Save is off, or null when it is on.
  final String? problem;

  final bool isSaving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingSm,
        sizing.screenPaddingH,
        sizing.spacingSm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                problem == null
                    ? Icons.check_circle_rounded
                    : Icons.info_outline_rounded,
                size: sizing.iconXs,
                color: problem == null
                    ? AppColors.successStrong
                    : AppColors.textTertiary,
              ),
              SizedBox(width: sizing.spacingXxs),
              Expanded(
                child: Text(
                  problem != null
                      ? tr(problem!)
                      : availability.isSaveable
                      ? availabilitySummaryText(availability)
                      : tr('No hours set — you will not be offered calls'),
                  style: sizing.text.metaLabel.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: sizing.spacingXs),
          AppButton.primary(
            label: 'Save Availability',
            isLoading: isSaving,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
