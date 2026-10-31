import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/format/app_date_format.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/exit_confirmation.dart';
import '../../../../core/update/app_update_prompt.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../appointments/presentation/screens/appointments_screen.dart';
import '../../../appointments/presentation/widgets/appointment_card.dart';
import '../../../call/presentation/screens/call_screen.dart';
import '../../../consultation/domain/usecases/answer_consultations.dart';
import '../../../consultation/presentation/controllers/doctor_search_session.dart';
import '../../../consultation/presentation/widgets/doctor_search_card.dart';
import '../../../doctors/domain/entities/doctor.dart';
import '../../../doctors/domain/entities/speciality.dart';
import '../../../doctors/presentation/screens/doctor_detail_screen.dart';
import '../../../doctors/presentation/screens/doctor_list_screen.dart';
import '../../../profile/presentation/screens/patient_profile_screen.dart';
import '../controllers/patient_home_controller.dart';
import '../widgets/active_consultation_banner.dart';
import '../widgets/consult_consent_dialog.dart';
import '../../../recordings/presentation/screens/recordings_chat_screen.dart';
import '../widgets/patient_nav_bar.dart';
import '../widgets/patient_greeting_header.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/section_header.dart';
import '../widgets/speciality_tile.dart';
import '../../../../core/l10n/tr.dart';

/// The patient's landing screen after onboarding.
class PatientHomeScreen extends StatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  State<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends State<PatientHomeScreen> {
  late final PatientHomeController _controller = sl<PatientHomeController>();

  /// The app-wide doctor search. Held rather than disposed: it belongs to the
  /// app and outlives every screen, which is the whole point of it — a search
  /// the patient backed out of is still running, and this is where they hear
  /// about it.
  late final DoctorSearchSession _search = sl<DoctorSearchSession>();

  PatientTab _tab = PatientTab.home;

  /// True while a rejoin is being brokered, so a second tap cannot open two
  /// calls into the same room.
  bool _isJoining = false;

  /// True while a request is being withdrawn.
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectTab(PatientTab tab) => setState(() => _tab = tab);

  /// Walks the patient back into a consultation that is still open.
  ///
  /// Through `join` rather than building the call from the row, because `join`
  /// answers with the channel, this device's peer id and which side dials — the
  /// three things the dashboard does not carry and the app must not guess.
  Future<void> _rejoin(Appointment appointment) async {
    if (_isJoining) return;
    setState(() => _isJoining = true);

    try {
      final consultation = await sl<ManageConsultationCall>().join(
        appointment.id,
      );

      if (!mounted) return;

      await Navigator.of(context).pushNamed(
        AppRoutes.call,
        arguments: CallArgs.fromConsultation(consultation),
      );

      // The call clears the banner and changes the figures, so the dashboard is
      // stale the moment it ends.
      if (mounted) await _controller.load();
    } on Failure catch (failure) {
      if (!mounted) return;
      AppSnackBar.error(context, failure.message);
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  /// Withdraws a request the patient has given up on.
  ///
  /// Confirmed first, because it is not undoable: the place in the queue goes,
  /// and asking again starts from the back. Then the dashboard is re-read, which
  /// is what takes the card off the screen — the server is the authority on
  /// whether the request is still open, so the card is not hidden locally and
  /// hoped about.
  Future<void> _cancelSearch(Appointment appointment) async {
    if (_isCancelling) return;

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Stop looking?',
      message:
          'We will withdraw your request. '
          'You can ask for a doctor again whenever you like.',
      confirmLabel: 'Stop looking',
      cancelLabel: 'Keep waiting',
      icon: Icons.search_off_rounded,
      tone: AppConfirmTone.destructive,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isCancelling = true);

    try {
      await sl<ManageConsultationCall>().cancel(appointment.id);
      if (!mounted) return;

      AppSnackBar.info(context, 'Request withdrawn.');
      await _controller.load();
    } on Failure catch (failure) {
      if (!mounted) return;
      AppSnackBar.error(context, failure.message);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  /// Opens the doctors the background search found.
  ///
  /// The search is cleared on the way, because it has now been answered: the
  /// card exists from the moment a search starts until the patient has looked
  /// at what it found, and no longer.
  void _openSearchResults() {
    final args = DoctorListArgs(
      speciality: _search.speciality,
      instantOnly: _search.instantOnly,
    );

    _search.clear();
    Navigator.of(context).pushNamed(AppRoutes.doctorList, arguments: args);
  }

  /// Runs the same search again after one that found nobody, or failed.
  void _retrySearch() {
    _search.start(
      speciality: _search.speciality,
      instantOnly: _search.instantOnly,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Nothing behind this screen, so the back gesture would close the
    // app outright — see [ExitConfirmation]. From another tab, back lands on
    // the dashboard first; only there does it ask to close.
    return ExitConfirmation(
      onBack: () {
        if (_tab == PatientTab.home) return false;
        _selectTab(PatientTab.home);
        return true;
      },
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
              Expanded(
                // Each tab is a body rather than a pushed route, so the nav bar
                // stays visible and the patient keeps their bearings.
                child: switch (_tab) {
                  PatientTab.home => _HomeBody(
                    controller: _controller,
                    search: _search,
                    isJoining: _isJoining,
                    isCancelling: _isCancelling,
                    onRejoin: _rejoin,
                    onCancelSearch: _cancelSearch,
                    onOpenSearchResults: _openSearchResults,
                    onRetrySearch: _retrySearch,
                    onOpenProfile: () => _selectTab(PatientTab.profile),
                    onSeeAppointments: () =>
                        _selectTab(PatientTab.appointments),
                  ),
                  PatientTab.appointments => const AppointmentsView(
                    audience: AppointmentAudience.patient,
                  ),
                  PatientTab.profile => const PatientProfileView(),
                },
              ),
              // Raises the update sheet once per launch; draws nothing.
              const AppUpdatePrompter(),
              PatientNavBar(current: _tab, onSelected: _selectTab),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.controller,
    required this.search,
    required this.isJoining,
    required this.isCancelling,
    required this.onRejoin,
    required this.onCancelSearch,
    required this.onOpenSearchResults,
    required this.onRetrySearch,
    required this.onOpenProfile,
    required this.onSeeAppointments,
  });

  final PatientHomeController controller;

  /// The background doctor search, reported as a card above everything else.
  final DoctorSearchSession search;

  final VoidCallback onOpenSearchResults;
  final VoidCallback onRetrySearch;
  final bool isJoining;
  final bool isCancelling;
  final ValueChanged<Appointment> onRejoin;

  /// Withdraws a request the patient has given up on, which is what dismisses
  /// the card.
  final ValueChanged<Appointment> onCancelSearch;

  /// Switches to the Profile tab rather than pushing a route, so the summary
  /// card and the nav bar lead to the same place.
  final VoidCallback onOpenProfile;

  final VoidCallback onSeeAppointments;

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

        return AppRefreshIndicator(
          onRefresh: controller.load,
          child: ListView(
            padding: EdgeInsets.only(bottom: sizing.spacingXxl),
            children: [
              // The greeting and nothing else. The three running totals that
              // used to sit under it — consults, doctors, spend — are a record
              // rather than a thing to act on, and they live on the profile now.
              PatientGreetingHeader(
                firstName: dashboard.firstName,
                avatarPath: dashboard.photoUrl,
                initials: dashboard.patientName.trim().isEmpty
                    ? null
                    : dashboard.initials,
                onOpenProfile: onOpenProfile,
                onSearch: () => Navigator.of(context).pushNamed(
                  AppRoutes.doctorList,
                  arguments: const DoctorListArgs(searchFirst: true),
                ),
              ),
              // Directly under the greeting: a consultation the patient is in
              // the middle of, or still waiting on, is more urgent than
              // whatever they opened the app to do. Before this banner existed
              // there was no way back into a call the app had been
              // backgrounded during — and no way to call off a search either.
              if (dashboard.active case final active?)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    sizing.screenPaddingH,
                    sizing.spacingMd,
                    sizing.screenPaddingH,
                    0,
                  ),
                  child: ActiveConsultationBanner(
                    appointment: active,
                    isBusy: isJoining,
                    isCancelling: isCancelling,
                    onRejoin: () => onRejoin(active),
                    onCancel: () => onCancelSearch(active),
                  ),
                ),
              // A doctor search the patient started and then left. It runs on
              // in `DoctorSearchSession`, and this is the only place it
              // surfaces — without it, backing out of the search screen threw
              // the search away with nothing said.
              //
              // Rebuilt from the session rather than from the feed, because it
              // changes on its own clock: the dashboard is not reloaded when a
              // search finishes, and a card that only updated on a pull to
              // refresh would sit at "Finding a doctor" after it had found one.
              ListenableBuilder(
                listenable: search,
                builder: (context, _) {
                  if (!search.isActive) return const SizedBox.shrink();

                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      sizing.screenPaddingH,
                      sizing.spacingMd,
                      sizing.screenPaddingH,
                      0,
                    ),
                    child: DoctorSearchCard(
                      session: search,
                      onOpen: onOpenSearchResults,
                      onDismiss: search.clear,
                      onRetry: onRetrySearch,
                    ),
                  );
                },
              ),
              SizedBox(height: sizing.spacingMd),
              if (controller.errorMessage != null)
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: sizing.screenPaddingH,
                  ),
                  child: _FeedError(
                    message: controller.errorMessage!,
                    onRetry: controller.load,
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: sizing.screenPaddingH,
                ),
                child: Column(
                  children: [
                    QuickActionCard(
                      title: 'Anonymous consultation',
                      subtitle: 'Talk to a doctor privately',
                      icon: Icons.person_off_rounded,
                      accent: AppColors.anonymousAccent,
                      onTap: () => _openAfterConsent(
                        context,
                        ConsultConsent.anonymous,
                        AppRoutes.anonymousBooking,
                      ),
                    ),
                    SizedBox(height: sizing.spacingSm),
                    QuickActionCard(
                      title: 'Video consultation',
                      subtitle: 'Connect instantly with a doctor',
                      icon: Icons.video_call_rounded,
                      accent: AppColors.consultAccent,
                      // Into the options screen, where the patient chooses
                      // between a doctor now and a booking, and then the call
                      // type. It used to jump straight into a call with a
                      // hard-coded doctor in a room called `consult-room-1` —
                      // one room for every patient in the world, and nobody on
                      // the other end of it.
                      onTap: () => _openAfterConsent(
                        context,
                        ConsultConsent.video,
                        AppRoutes.consultOptions,
                      ),
                    ),
                  ],
                ),
              ),
              // Right under the two ways to consult: picking a speciality is
              // the third way in, so it sits with the other two.
              //
              // The patient's own specialities first, commonest first, then the
              // rest of the catalogue — one tile was all a patient with one past
              // consultation ever got here.
              SizedBox(height: sizing.spacingXl),
              _Section(
                title: 'By speciality',
                actionLabel: 'See All',
                // The listing with no speciality filter, which *is* all of
                // them.
                onActionTap: () => _openDoctors(context, null),
                child: _SpecialityRow(
                  specialities: _browseSpecialities(dashboard.specialities),
                  onTap: (speciality) => _openDoctors(context, speciality),
                ),
              ),
              // Only the latest consultation lives on the home screen. The
              // rest are a history, and the history has its own section —
              // the Appointments tab in the nav bar.
              if (dashboard.lastConsultation case final last?) ...[
                SizedBox(height: sizing.spacingXl),
                _Section(
                  title: 'Last consultation',
                  actionLabel: 'History',
                  onActionTap: onSeeAppointments,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppointmentCard(
                        appointment: last,
                        onRejoin: isJoining ? null : () => onRejoin(last),
                        onViewReceipt: () => Navigator.of(context).pushNamed(
                          AppRoutes.consultationReceipt,
                          arguments: last,
                        ),
                        onOpenChat: () => openRecordingsChat(context, last),
                      ),
                    ],
                  ),
                ),
              ],
              // The doctors this patient has actually seen, each a tap from a
              // second consultation. Absent until there is one.
              if (dashboard.recentDoctors.isNotEmpty) ...[
                SizedBox(height: sizing.spacingXl),
                _Section(
                  title: 'Consult again',
                  actionLabel: 'See All',
                  onActionTap: () => _openDoctors(context, null),
                  child: _RecentDoctorsRow(
                    appointments: dashboard.recentDoctors,
                    onTap: (appointment) => _openDoctor(context, appointment),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Asks for consent, then opens [route].
///
/// Every time, not once: what the patient is agreeing to — recording only
/// with consent, no prescription when anonymous — is the thing most likely to
/// be forgotten between one consultation and the next.
Future<void> _openAfterConsent(
  BuildContext context,
  ConsultConsent consent,
  String route,
) async {
  final agreed = await ConsultConsentDialog.show(context, consent);

  if (!agreed || !context.mounted) return;
  await Navigator.of(context).pushNamed(route);
}

/// Opens the doctor listing, scoped to [speciality] or to every doctor.
void _openDoctors(BuildContext context, Speciality? speciality) {
  Navigator.of(context).pushNamed(
    AppRoutes.doctorList,
    arguments: DoctorListArgs(speciality: speciality),
  );
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.actionLabel,
    required this.onActionTap,
    required this.child,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onActionTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sizing.screenPaddingH),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: title,
            actionLabel: actionLabel,
            onActionTap: onActionTap,
          ),
          SizedBox(height: sizing.spacingSm),
          child,
        ],
      ),
    );
  }
}

/// Opens one past doctor's profile, from where they can be consulted now or
/// booked. The row carries only the name and speciality; the profile screen
/// fetches the rest by id.
void _openDoctor(BuildContext context, Appointment appointment) {
  Navigator.of(context).pushNamed(
    AppRoutes.doctorDetail,
    arguments: DoctorDetailArgs(
      doctor: Doctor(
        id: appointment.counterpartId!,
        name: appointment.counterpartName,
        speciality: appointment.counterpartSubtitle,
        yearsOfExperience: 0,
        rating: 0,
        consultationFee: appointment.fee ?? 0,
        registrationNumber: appointment.counterpartRegistrationNumber,
      ),
    ),
  );
}

/// The specialities doctors register under, in the names the directory
/// filters on exactly. Matches the onboarding list.
///
/// The first two are pinned to the front of the row, ahead of the patient's
/// own history — they are the two the service leads with.
const _pinnedSpecialities = ['Stress Management', 'Internal Medicine'];

const _catalogueSpecialities = [
  ..._pinnedSpecialities,
  'Dermatology',
  'Paediatrics',
  'Cardiology',
  'Neurology',
  'Dentistry',
];

/// The patient's own specialities first, commonest first, then the rest of
/// the catalogue — so the row is never a single lonely tile.
List<Speciality> _browseSpecialities(List<Speciality> own) {
  final seen = <String>{};
  return [
    for (final name in _pinnedSpecialities)
      if (seen.add(name.toLowerCase())) Speciality.named(name),
    for (final speciality in own)
      if (seen.add(speciality.id.toLowerCase())) speciality,
    for (final name in _catalogueSpecialities)
      if (seen.add(name.toLowerCase())) Speciality.named(name),
  ];
}

class _SpecialityRow extends StatelessWidget {
  const _SpecialityRow({required this.specialities, required this.onTap});

  final List<Speciality> specialities;
  final ValueChanged<Speciality> onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    // Scrolls sideways, bleeding past the screen padding so the last tile is
    // visibly cut — the cue that there is more.
    // Tall enough for a two-line name: "Stress Management" and "Internal
    // Medicine" were cut to "Internal M…" on one line.
    return SizedBox(
      height: sizing.r(132),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: specialities.length,
        separatorBuilder: (_, _) => SizedBox(width: sizing.spacingSm),
        itemBuilder: (context, index) {
          final speciality = specialities[index];
          return SizedBox(
            width: sizing.r(92),
            child: SpecialityTile(
              speciality: speciality,
              onTap: () => onTap(speciality),
            ),
          );
        },
      ),
    );
  }
}

/// The doctors the patient has seen, newest first, each a tap from their
/// profile and a second consultation.
class _RecentDoctorsRow extends StatelessWidget {
  const _RecentDoctorsRow({required this.appointments, required this.onTap});

  final List<Appointment> appointments;
  final ValueChanged<Appointment> onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return SizedBox(
      height: sizing.r(168),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: appointments.length,
        separatorBuilder: (_, _) => SizedBox(width: sizing.spacingSm),
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          return SizedBox(
            width: sizing.r(148),
            child: _RecentDoctorCard(
              appointment: appointment,
              onTap: () => onTap(appointment),
            ),
          );
        },
      ),
    );
  }
}

class _RecentDoctorCard extends StatelessWidget {
  const _RecentDoctorCard({required this.appointment, required this.onTap});

  final Appointment appointment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final radius = BorderRadius.circular(sizing.radiusLg);

    return Material(
      color: AppColors.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.all(sizing.spacingSm),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(width: sizing.hairline, color: AppColors.border),
          ),
          child: Column(
            children: [
              RemoteAvatar(
                path: null,
                initials: initialsOf(appointment.counterpartName),
                size: sizing.avatarSize,
                semanticLabel: appointment.counterpartName,
              ),
              SizedBox(height: sizing.spacingXs),
              Text(
                appointment.counterpartName,
                style: sizing.text.cardTitle.copyWith(
                  fontSize: sizing.sp(13),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                appointment.counterpartSubtitle.isEmpty
                    ? tr('Doctor')
                    : tr(appointment.counterpartSubtitle),
                style: sizing.text.metaLabel,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                tr('Last: {date}', {
                  'date': AppDateFormat.dayMonth(appointment.occursAt),
                }),
                style: sizing.text.metaLabel.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: sizing.sp(11),
                ),
              ),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: sizing.spacingXxs),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(sizing.radiusSm),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.replay_rounded,
                      size: sizing.iconXs,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: sizing.spacingXxs),
                    Text(
                      tr('Consult'),
                      style: sizing.text.metaLabel.copyWith(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

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
