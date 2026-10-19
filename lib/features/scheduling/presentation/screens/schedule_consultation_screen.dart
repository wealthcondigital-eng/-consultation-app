import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../anonymous/domain/entities/anonymous_session.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../payment/presentation/screens/payment_screen.dart';
import '../../domain/entities/doctor_schedule.dart';
import '../../domain/entities/time_slot.dart';
import '../controllers/schedule_consultation_controller.dart';
import '../widgets/booking_summary_card.dart';
import '../widgets/consultation_type_picker.dart';
import '../widgets/schedule_date_strip.dart';
import '../widgets/schedule_doctor_card.dart';
import '../widgets/slot_period_group.dart';

/// Who the appointment is with, and how the patient said they wanted it.
class ScheduleConsultationArgs {
  const ScheduleConsultationArgs({
    required this.doctor,
    this.mode = ConsultationMode.video,
    this.anonymousSession,
    this.initialSlot,
  });

  /// A time the patient already picked on the doctor's profile. The grid opens
  /// on it rather than asking the question a second time.
  final OpenSlot? initialSlot;

  final Doctor doctor;

  /// The call type chosen before browsing. The patient can still change it here.
  final ConsultationMode mode;

  /// Set when the patient is booking under an alias. The booking is filed with
  /// that name and the concern they wrote, exactly as an anonymous instant
  /// consultation is — the only difference is when it happens.
  final AnonymousSession? anonymousSession;

  bool get isAnonymous => anonymousSession != null;
}

/// Pick a day, a time and a call type, then book.
class ScheduleConsultationScreen extends StatefulWidget {
  const ScheduleConsultationScreen({super.key, required this.args});

  final ScheduleConsultationArgs args;

  @override
  State<ScheduleConsultationScreen> createState() =>
      _ScheduleConsultationScreenState();
}

class _ScheduleConsultationScreenState
    extends State<ScheduleConsultationScreen> {
  late final ScheduleConsultationController _controller =
      sl<ScheduleConsultationController>();

  @override
  void initState() {
    super.initState();
    _controller.load(
      doctorId: widget.args.doctor.id,
      mode: widget.args.mode,
      startingAt: widget.args.initialSlot?.startsAt,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Doctor get _doctor => widget.args.doctor;

  /// What the chosen call type costs with this doctor.
  String get _feeLabel => _doctor.formatFee(_doctor.feeFor(_controller.mode));

  Future<void> _confirm() async {
    if (!_controller.canConfirm) return;

    // Payment is the last step: the slot is held once it is paid for.
    await Navigator.of(context).pushNamed(
      AppRoutes.payment,
      arguments: PaymentArgs(
        doctor: _doctor,
        mode: _controller.mode,
        scheduledFor: _controller.appointmentLabel,
        // The moment, not just the sentence. Payment is where the booking is
        // actually filed, and a label is not something a diary can hold —
        // which is why the appointment never reached the doctor before.
        scheduledAt: _controller.selectedSlotAt,
        anonymousSession: widget.args.anonymousSession,
      ),
    );

    // Read the grid again whichever way it went. A failed booking may have
    // failed *because* somebody took the slot, and the grid would otherwise go
    // on showing it as free and selected. A paid one completes this await too
    // — `pushReplacementNamed` finishes the route it replaces — and then the
    // slot is simply greyed out underneath the confirmation, which is right.
    if (mounted) await _controller.refresh(doctorId: _doctor.id);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        scrollable: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppTopBar(
                  title: 'Schedule Consultation',
                  variant: AppTopBarVariant.outlined,
                  centerTitle: true,
                ),
                Expanded(child: _Body(state: this)),
                _ConfirmBar(state: this),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final _ScheduleConsultationScreenState state;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final controller = state._controller;
    final schedule = controller.schedule;
    final day = controller.selectedDay;

    if (schedule == null || day == null) {
      return controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: sizing.screenPadding,
                child: Text(
                  tr(
                    controller.errorMessage ??
                        'This doctor has no slots open right now.',
                  ),
                  style: sizing.text.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingMd,
        sizing.screenPaddingH,
        sizing.spacingXl,
      ),
      children: [
        ScheduleDoctorCard(doctor: state._doctor),
        SizedBox(height: sizing.spacingXl),
        Text(tr('SELECT DATE'), style: sizing.text.listTitle),
        SizedBox(height: sizing.spacingSm),
        ScheduleDateStrip(
          days: schedule.days,
          selectedIndex: controller.selectedDayIndex,
          onDaySelected: controller.selectDay,
        ),
        SizedBox(height: sizing.spacingXl),
        Text(tr('AVAILABLE TIME SLOTS'), style: sizing.text.listTitle),
        SizedBox(height: sizing.spacingSm),
        // A doctor who works mornings has no afternoon, and a heading over an
        // empty row reads as slots that failed to load.
        for (final period in SlotPeriod.values.where(
          (period) => day.slotsIn(period).isNotEmpty,
        )) ...[
          SizedBox(height: sizing.spacingMd),
          SlotPeriodGroup(
            period: period,
            slots: day.slotsIn(period),
            selectedSlot: controller.selectedSlot,
            onSlotSelected: controller.selectSlot,
          ),
        ],
        SizedBox(height: sizing.spacingXl),
        Text(tr('CONSULTATION TYPE'), style: sizing.text.listTitle),
        SizedBox(height: sizing.spacingSm),
        ConsultationTypePicker(
          selected: controller.mode,
          onChanged: controller.changeMode,
        ),
        SizedBox(height: sizing.spacingXl),
        BookingSummaryCard(
          durationLabel: schedule.durationLabel,
          feeLabel: state._feeLabel,
          appointmentLabel: controller.appointmentLabel,
        ),
      ],
    );
  }
}

/// The book action, pinned below the scrolling picker.
class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({required this.state});

  final _ScheduleConsultationScreenState state;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final controller = state._controller;

    return Container(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingSm,
        sizing.screenPaddingH,
        sizing.spacingMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!controller.canConfirm) ...[
            Text(
              tr('Pick a time slot to continue'),
              style: sizing.text.caption,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: sizing.spacingXs),
          ],
          AppButton.primary(
            label: 'Confirm Booking',
            onPressed: controller.canConfirm ? state._confirm : null,
          ),
        ],
      ),
    );
  }
}
