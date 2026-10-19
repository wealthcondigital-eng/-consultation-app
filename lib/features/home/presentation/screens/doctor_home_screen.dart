import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/device/call_device.dart';
import '../../../../core/device/call_permissions.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/push/call_kit_bridge.dart';
import '../../../../core/push/incoming_call_push.dart';
import '../../../../core/push/push_service.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/exit_confirmation.dart';
import '../../../../core/update/app_update_prompt.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../call/presentation/controllers/active_call.dart';
import '../../../call/presentation/screens/call_screen.dart';
import '../../../consultation/domain/entities/live_consultation.dart';
import '../../../consultation/domain/usecases/answer_consultations.dart';
import '../../../consultation/presentation/controllers/incoming_consultation_controller.dart';
import '../../../consultation/presentation/widgets/incoming_call_banner.dart';
import '../../../doctor_practice/presentation/screens/doctor_earnings_screen.dart';
import '../../../doctor_practice/presentation/screens/doctor_patients_screen.dart';
import '../../../doctor_profile/presentation/screens/doctor_profile_screen.dart';
import '../../domain/entities/doctor_appointment.dart';
import '../../domain/entities/doctor_dashboard.dart';
import '../controllers/doctor_home_controller.dart';
import '../controllers/ring_readiness_controller.dart';
import '../widgets/doctor_appointment_card.dart';
import '../widgets/patient_details_sheet.dart';
import '../widgets/doctor_nav_bar.dart';
import '../widgets/doctor_greeting_header.dart';
import '../widgets/presence_dial.dart';
import '../widgets/ring_setup.dart';
import '../widgets/section_header.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/l10n/tr.dart';

/// The doctor's home: whether they are online, the day so far, and who is next.
class DoctorHomeScreen extends StatefulWidget {
  const DoctorHomeScreen({super.key});

  @override
  State<DoctorHomeScreen> createState() => _DoctorHomeScreenState();
}

class _DoctorHomeScreenState extends State<DoctorHomeScreen> {
  late final DoctorHomeController _controller = sl<DoctorHomeController>();

  /// Watches for a patient calling. Started here rather than on a screen of its
  /// own because its poll is also the doctor's presence heartbeat — a doctor
  /// marked online whom nobody is polling stops being offered calls, which is
  /// the point.
  late final IncomingConsultationController _incoming =
      sl<IncomingConsultationController>();

  /// Where an Accept on the phone's own ringing screen arrives — the screen a
  /// doctor sees when the app was in the background or killed.
  late final CallKitBridge _callKit = sl<CallKitBridge>();

  /// Whether this phone will actually ring with the app closed.
  late final RingReadinessController _readiness = sl<RingReadinessController>();

  /// Re-reads the phone's settings each time the doctor comes back from one.
  late final AppLifecycleListener _lifecycle;

  /// The setup sheet opens by itself once, the first time the doctor goes
  /// Online with something missing. After that it is the card's to offer.
  bool _promptedSetup = false;

  DoctorTab _tab = DoctorTab.home;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onChanged)
      ..load();
    _incoming
      ..addListener(_onIncomingChanged)
      ..start();

    _callKit.accepted.addListener(_onAcceptedOnPhone);
    // The Accept that launched the app is usually already waiting by the time
    // this screen exists — it came in behind the splash screen.
    _onAcceptedOnPhone();
    unawaited(_callKit.recoverSoon());

    _lifecycle = AppLifecycleListener(onResume: _readiness.refresh);
    unawaited(_readiness.refresh());

    // The microphone and camera, asked for now rather than at the first
    // Accept. A doctor can be rung at any moment, and answering one from the
    // lock screen is the worst place to meet a permission prompt.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(CallPermissions.warmUp());
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _readiness.dispose();
    _callKit.accepted.removeListener(_onAcceptedOnPhone);
    // Signed out, say, with a call ringing: nobody left here to answer it.
    if (_ringingId case final id?) unawaited(_callKit.stopRinging(id));
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    _incoming
      ..removeListener(_onIncomingChanged)
      ..dispose();
    super.dispose();
  }

  /// Answers a call accepted on the ringing screen. The server is told here,
  /// not there: the ringing screen has no session, and the app does.
  void _onAcceptedOnPhone() {
    final consultationId = _callKit.take();
    if (consultationId == null || !mounted) return;

    unawaited(_answerFromPhone(consultationId));
  }

  /// The presence dial. Going Online on a phone that will not ring with the
  /// app closed opens the setup sheet — the moment the doctor is promising to
  /// be reachable is the moment to say they may not be.
  Future<void> _togglePresence() async {
    final wasOnline = _controller.dashboard.isOnline;
    await _controller.togglePresence();

    if (wasOnline || !_controller.dashboard.isOnline || _promptedSetup) return;

    await _readiness.refresh();
    if (!mounted || _readiness.isReady) return;

    _promptedSetup = true;
    _openRingSetup();
  }

  void _openRingSetup() {
    RingSetupSheet.show(context, controller: _readiness);
  }

  Future<void> _answerFromPhone(String consultationId) async {
    // Opens the call through [_onIncomingChanged] on success, and puts the
    // reason on screen on failure — usually that it rang out while the phone
    // was starting the app.
    await _incoming.acceptById(consultationId);

    // Either way the phone's own call is finished with: answered and handed to
    // the call screen, or gone.
    await PushService.dismissCall(consultationId);

    // An Accept on a locked phone put the app over the lock screen so the call
    // could be seen. With no call to see, it must not stay there for whoever
    // picks the phone up next.
    if (_incoming.accepted == null && !_inCall) {
      unawaited(CallDevice.showOverLockScreen(false));
    }
  }

  /// The call the phone is ringing for, as far as this screen knows.
  String? _ringingId;

  /// True while a call screen is open over this one. Nothing rings then.
  bool _inCall = false;

  /// Keeps the phone ringing for exactly the call the poll says is ringing.
  ///
  /// The push rings the phone too, and usually first; this is for the push that
  /// never came — a token the server lost, a message held back by the phone —
  /// which used to leave a silent banner as the only sign of a patient waiting.
  void _syncRing() {
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final consultation = _incoming.hasIncoming ? _incoming.incoming : null;
    final id = consultation?.id;
    if (id == _ringingId) return;

    final previous = _ringingId;
    _ringingId = id;

    if (previous != null) unawaited(_callKit.stopRinging(previous));
    // A call carries on after its screen closes (see ActiveCall), so "in a
    // call" is the call service's to answer, not whether a screen is open.
    if (consultation == null || _inCall || sl<ActiveCall>().isActive) return;

    unawaited(
      _callKit.ring(
        IncomingCallPush(
          consultationId: consultation.id,
          channelId: consultation.channelId,
          mode: consultation.mode,
          callerName: consultation.patientName.trim().isEmpty
              ? 'A patient'
              : consultation.patientName.trim(),
          concern: consultation.concern,
          // The poll only says it is ringing, not for how much longer. It is
          // taken down by the poll when it stops, whichever comes first.
          ringSeconds: 45,
        ),
      ),
    );
  }

  /// Opens the call the doctor just accepted, and surfaces a ring that was
  /// already gone by the time they reached for the phone.
  void _onIncomingChanged() {
    if (!mounted) return;

    _syncRing();

    if (_incoming.errorMessage case final message?) {
      _incoming.clearError();
      AppSnackBar.error(context, message);
    }

    // Taken rather than read, so returning from the call does not reopen it.
    if (_incoming.takeAccepted() case final consultation?) {
      _openCall(consultation);
    }
  }

  Future<void> _openCall(LiveConsultation consultation) async {
    // The tray entry is a call that is ringing. Once it is answered here it is
    // not, and a notification that keeps ringing after the doctor has picked
    // up is one they have to go and silence mid-consultation.
    _inCall = true;
    _ringingId = null;
    await PushService.dismissCall(consultation.id);

    // Before the call screen touches the microphone: the ringing call, if the
    // doctor answered one, still owns the phone's call audio. See
    // [CallKitBridge.releaseAudio].
    await CallKitBridge.releaseAudio();
    if (!mounted) return;

    try {
      await Navigator.of(context).pushNamed(
        AppRoutes.call,
        arguments: CallArgs.fromConsultation(consultation),
      );
    } finally {
      _inCall = false;
    }

    // The call changes the day's numbers and clears the appointment off the
    // list, so the dashboard is stale the moment it ends.
    if (mounted) await _controller.load();
  }

  /// Opens a consultation already on the dashboard.
  ///
  /// Goes through `join` rather than building the call from the appointment
  /// card, because `join` answers with the channel, this device's peer id and
  /// which side dials — the three things the card does not carry and the app
  /// must not guess.
  Future<void> _startAppointment(String consultationId) async {
    try {
      final consultation = await sl<ManageConsultationCall>().join(
        consultationId,
      );
      if (mounted) await _openCall(consultation);
    } on Failure catch (failure) {
      if (!mounted) return;
      AppSnackBar.error(context, failure.message);
    }
  }

  /// Surfaces a presence change the backend refused. The dial has already
  /// reverted by the time this runs.
  void _onChanged() {
    final message = _controller.errorMessage;
    if (message == null || !mounted) return;

    _controller.acknowledgeError();
    AppSnackBar.error(context, message);
  }

  void _selectTab(DoctorTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    // Nothing behind this screen, so the back gesture would close the
    // app outright — see [ExitConfirmation].
    return ExitConfirmation(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppColors.overlayOnCanvas.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.surface,
          systemNavigationBarIconBrightness: AppColors.navIconBrightness,
        ),
        child: ResponsivePage(
          backgroundColor: AppColors.canvas,
          // The body scrolls itself so the nav bar can stay pinned below it.
          scrollable: false,
          child: Column(
            children: [
              // Above everything, on every tab: a patient waiting is more urgent
              // than whatever the doctor was looking at, and the ring only lasts
              // thirty seconds before it goes to somebody else.
              ListenableBuilder(
                listenable: _incoming,
                builder: (context, _) {
                  final consultation = _incoming.incoming;
                  if (consultation == null || !_incoming.hasIncoming) {
                    return const SizedBox.shrink();
                  }

                  return IncomingCallBanner(
                    consultation: consultation,
                    isBusy: _incoming.isAnswering,
                    onAccept: _incoming.accept,
                    onDecline: _incoming.decline,
                  );
                },
              ),
              Expanded(
                // Each tab is a body rather than a pushed route, so the nav bar
                // stays put — these are destinations, not detours.
                child: switch (_tab) {
                  DoctorTab.home => _Dashboard(
                    controller: _controller,
                    readiness: _readiness,
                    onTogglePresence: _togglePresence,
                    onOpenRingSetup: _openRingSetup,
                    onStartAppointment: _startAppointment,
                    onOpenProfile: () => _selectTab(DoctorTab.profile),
                  ),
                  DoctorTab.patients => const DoctorPatientsView(),
                  DoctorTab.earnings => const DoctorEarningsView(),
                  DoctorTab.profile => const DoctorProfileView(),
                },
              ),
              // Raises the update sheet once per launch; draws nothing.
              const AppUpdatePrompter(),
              DoctorNavBar(current: _tab, onSelected: _selectTab),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.controller,
    required this.readiness,
    required this.onTogglePresence,
    required this.onOpenRingSetup,
    required this.onStartAppointment,
    required this.onOpenProfile,
  });

  final DoctorHomeController controller;

  /// Drives the "calls may not ring" card under the dial.
  final RingReadinessController readiness;

  final VoidCallback onTogglePresence;
  final VoidCallback onOpenRingSetup;

  /// Switches to the Profile tab, from the avatar in the header.
  final VoidCallback onOpenProfile;

  /// Takes the consultation's id. The appointment *is* the consultation, so
  /// there is nothing else to pass.
  final ValueChanged<String> onStartAppointment;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.isInitialLoad) {
          return const Center(child: CircularProgressIndicator());
        }

        final dashboard = controller.dashboard;

        // Cut into days by the entity, so Today comes first, then Tomorrow,
        // then each date. Worked out once: the count above the list and the
        // list itself must agree on what is still ahead.
        final days = dashboard.appointmentDays();
        final upcoming = days.fold<int>(
          0,
          (total, day) => total + day.appointments.length,
        );

        return AppRefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: EdgeInsets.only(bottom: sizing.spacingXxl),
            children: [
              // Full-bleed: the gradient runs to both edges and under the
              // status bar.
              DoctorGreetingHeader(
                doctorName: dashboard.doctorName,
                speciality: dashboard.speciality,
                isOnline: dashboard.isOnline,
                photoPath: dashboard.photoUrl,
                onOpenProfile: onOpenProfile,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  sizing.screenPaddingH,
                  sizing.spacingXl,
                  sizing.screenPaddingH,
                  sizing.spacingLg,
                ),
                child: Column(
                  children: [
                    PresenceDial(
                      isOnline: dashboard.isOnline,
                      isBusy: controller.isSwitchingPresence,
                      onTap: onTogglePresence,
                    ),
                    SizedBox(height: sizing.spacingLg),
                    PresenceNote(isOnline: dashboard.isOnline),
                    // Only while Online: an Offline doctor is not waiting to
                    // be rung, so the phone's settings are not their problem.
                    ListenableBuilder(
                      listenable: readiness,
                      builder: (context, _) {
                        if (!dashboard.isOnline ||
                            !readiness.hasLoaded ||
                            readiness.isReady) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: EdgeInsets.only(top: sizing.spacingMd),
                          child: RingSetupCard(
                            missingCount: readiness.missing.length,
                            onTap: onOpenRingSetup,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // The day's statistics moved to the profile. What the home
              // screen answers now is how much is ahead and how much is done.
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: sizing.screenPaddingH,
                ),
                child: _AppointmentCounts(
                  upcoming: upcoming,
                  completed: dashboard.stats.completedTotal,
                  onOpenCompleted: () => Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.doctorAppointments),
                ),
              ),
              SizedBox(height: sizing.spacingLg),
              _Section(
                title: 'Upcoming Appointments',
                child: _Appointments(
                  days: days,
                  // The real consultation, joined by id. It used to open a call
                  // to a hard-coded `Dr. Sarah Jenkins` in `consult-room-1` —
                  // a doctor calling a fictional doctor in a shared room.
                  onStart: (appointment) => onStartAppointment(appointment.id),
                  onOpenPatient: (appointment) => PatientDetailsSheet.show(
                    context,
                    appointment: appointment,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The schedule ahead, under a heading per day.
///
/// Day headings rather than one undifferentiated list: a doctor scanning this
/// needs to know at a glance where today ends, and a card that says "10:30 AM"
/// with no date beside it reads as this morning whichever day it is on.
class _Appointments extends StatelessWidget {
  const _Appointments({
    required this.days,
    required this.onStart,
    required this.onOpenPatient,
  });

  final List<DoctorAppointmentDay> days;
  final ValueChanged<DoctorAppointment> onStart;

  /// Opens who the patient is, from the name on the card.
  final ValueChanged<DoctorAppointment> onOpenPatient;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (days.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(sizing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(sizing.radiusLg),
          border: Border.all(width: sizing.hairline, color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(
              Icons.event_available_rounded,
              size: sizing.r(28),
              color: AppColors.textTertiary,
            ),
            SizedBox(height: sizing.spacingXs),
            Text(
              tr('Nothing booked yet.'),
              style: sizing.text.cardTitle,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: sizing.spacingXxs),
            Text(
              tr('Go online and patients can reach you straight away.'),
              style: sizing.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in days) ...[
          if (day != days.first) SizedBox(height: sizing.spacingMd),
          _DayHeading(day: day),
          SizedBox(height: sizing.spacingXs),
          for (final appointment in day.appointments) ...[
            if (appointment != day.appointments.first)
              SizedBox(height: sizing.spacingSm),
            DoctorAppointmentCard(
              appointment: appointment,
              onStart: () => onStart(appointment),
              onOpenPatient: () => onOpenPatient(appointment),
            ),
          ],
        ],
      ],
    );
  }
}

/// `Today · 3 consultations` — the day, and how full it is.
class _DayHeading extends StatelessWidget {
  const _DayHeading({required this.day});

  final DoctorAppointmentDay day;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final count = day.appointments.length;
    // `dayLabel` already speaks the active language.
    final isToday = day.label == tr('Today');

    return Row(
      children: [
        Container(
          width: sizing.r(6),
          height: sizing.r(6),
          decoration: BoxDecoration(
            // Today is the one the doctor acts on; the rest are information.
            color: isToday ? AppColors.primary : AppColors.textTertiary,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Text(
          day.label,
          style: sizing.text.cardTitle.copyWith(
            color: isToday ? AppColors.primaryDeep : AppColors.textLabel,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Expanded(
          child: Text(
            count == 1
                ? tr('{count} consultation', {'count': count})
                : tr('{count} consultations', {'count': count}),
            style: sizing.text.metaLabel.copyWith(
              color: AppColors.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sizing.screenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: title),
          SizedBox(height: sizing.spacingSm),
          child,
        ],
      ),
    );
  }
}

/// Two numbers side by side: what is still ahead, and what is done.
///
/// Replaces the four-card statistics grid, which moved to the profile. A
/// doctor opening the home screen is asking what is next, and "3 upcoming"
/// answers that where "₹300 billed today" does not.
class _AppointmentCounts extends StatelessWidget {
  const _AppointmentCounts({
    required this.upcoming,
    required this.completed,
    required this.onOpenCompleted,
  });

  /// Counted from the same days the list below renders, so the two agree.
  final int upcoming;

  /// Every consultation this doctor has completed, not only today's.
  final int completed;

  /// Opens the consultation history, which is where the completed ones are.
  final VoidCallback onOpenCompleted;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _CountTile(
              label: 'Upcoming',
              caption: upcoming == 1 ? 'appointment' : 'appointments',
              value: upcoming,
              icon: Icons.event_note_rounded,
              accent: AppColors.primary,
              surface: AppColors.primarySurface,
            ),
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: _CountTile(
              label: 'Completed',
              caption: completed == 1 ? 'consultation' : 'consultations',
              value: completed,
              icon: Icons.task_alt_rounded,
              accent: AppColors.success,
              surface: AppColors.successSurface,
              onTap: onOpenCompleted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.caption,
    required this.value,
    required this.icon,
    required this.accent,
    required this.surface,
    this.onTap,
  });

  final String label;

  /// `appointments` — the noun under the number.
  final String caption;

  final int value;
  final IconData icon;
  final Color accent;
  final Color surface;

  /// Null leaves the tile inert. Only a tile with somewhere to go shows the
  /// chevron.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    final content = Padding(
      padding: EdgeInsets.all(sizing.tilePadding),
      child: Row(
        children: [
          Container(
            width: sizing.r(40),
            height: sizing.r(40),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(sizing.radiusMd),
            ),
            child: Icon(icon, size: sizing.iconSm, color: accent),
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tr(label),
                  style: sizing.text.metaLabel.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$value',
                    style: sizing.text.amountTotal.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                  ),
                ),
                Text(
                  tr(caption),
                  style: sizing.text.metaLabel.copyWith(
                    color: AppColors.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: sizing.iconSm,
              color: AppColors.textTertiary,
            ),
        ],
      ),
    );

    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        side: BorderSide(width: sizing.hairline, color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Semantics(
              label: '$value ${tr(label)} ${tr(caption)}',
              child: content,
            )
          : InkWell(onTap: onTap, child: content),
    );
  }
}
