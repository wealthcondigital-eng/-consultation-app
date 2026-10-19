import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_choice_chips.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../anonymous/domain/entities/anonymous_session.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../domain/entities/doctor.dart';
import '../../domain/entities/doctor_list_filter.dart';
import '../../domain/entities/speciality.dart';
import '../../../consultation/presentation/widgets/consultation_mode_sheet.dart';
import '../../../payment/presentation/screens/payment_screen.dart';
import '../../../scheduling/presentation/screens/schedule_consultation_screen.dart';
import '../controllers/doctor_list_controller.dart';
import '../widgets/doctor_list_card.dart';
import 'doctor_detail_screen.dart';

/// Which listing to show. A null [speciality] lists every doctor.
class DoctorListArgs {
  const DoctorListArgs({
    this.speciality,
    this.mode,
    this.instantOnly = false,
    this.anonymousSession,
    this.searchFirst = false,
  });

  final Speciality? speciality;

  /// The call type already chosen. When set, doctors who do not take it are
  /// left out — the patient cannot book what the doctor does not offer.
  final ConsultationMode? mode;

  /// True when this list was opened from Instant Consultation.
  final bool instantOnly;

  /// Set when the patient is consulting under an alias. Booking then rings the
  /// doctor under that alias rather than going through scheduling.
  final AnonymousSession? anonymousSession;

  /// Opened from a search bar: titled Search, keyboard up on arrival.
  final bool searchFirst;

  bool get isAnonymous => anonymousSession != null;
}

/// Browse and book the doctors in a speciality.
class DoctorListScreen extends StatefulWidget {
  const DoctorListScreen({super.key, this.args = const DoctorListArgs()});

  final DoctorListArgs args;

  @override
  State<DoctorListScreen> createState() => _DoctorListScreenState();
}

class _DoctorListScreenState extends State<DoctorListScreen> {
  late final DoctorListController _controller = sl<DoctorListController>();
  final TextEditingController _searchTextController = TextEditingController();

  Speciality? get _speciality => widget.args.speciality;

  String get _title => switch (widget.args) {
    DoctorListArgs(searchFirst: true) => 'Search',
    DoctorListArgs(isAnonymous: true) => 'Doctors Online',
    DoctorListArgs(instantOnly: true) => 'Available Doctors',
    _ => _speciality?.listingHeading ?? 'Verified Doctors',
  };

  String get _searchHint =>
      _speciality?.searchHint ??
      (widget.args.searchFirst
          ? 'Search by doctor name or speciality'
          : 'Search doctors');

  @override
  void initState() {
    super.initState();
    _controller.load(
      specialityId: _speciality?.id,
      // Opened from Instant Consultation: list only doctors who can take a
      // call this minute. Showing someone who cannot answer is the difference
      // between a list and a waiting room.
      availableNow: widget.args.instantOnly,
    );
  }

  @override
  void dispose() {
    _searchTextController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _book(Doctor doctor) async {
    // The call type chosen from Consult Now is retained through browsing.
    final mode =
        widget.args.mode ??
        await ConsultationModeSheet.show(context, doctor: doctor);
    if (mode == null || !mounted) return;

    // An anonymous consult rings this doctor under the alias, through the same
    // matching flow as any other instant consultation. It used to open a chat
    // thread against a stub instead: no consultation was filed, the doctor was
    // never told anyone wanted them, and the alias never left the device.
    if (widget.args.anonymousSession case final session?) {
      // Booking under an alias is the same consultation filed for later, so it
      // goes through the same slot picker as any other booking and carries the
      // session with it. Without this branch an anonymous patient who chose
      // "Book a slot" was rung immediately instead.
      if (session.isScheduled) {
        await Navigator.of(context).pushNamed(
          AppRoutes.scheduleConsultation,
          arguments: ScheduleConsultationArgs(
            doctor: doctor,
            mode: mode,
            anonymousSession: session,
          ),
        );
        return;
      }

      // Through payment, like every other instant consultation. The alias
      // travels with it and is carried on to matching by the confirmation.
      await Navigator.of(context).pushNamed(
        AppRoutes.payment,
        arguments: PaymentArgs(
          doctor: doctor,
          mode: mode,
          anonymousSession: session,
        ),
      );
      return;
    }

    // An instant consult rings this doctor now — there is no slot to pick, so
    // payment is the only step between choosing them and their phone ringing.
    //
    // **Through payment, not straight to matching**, and that was the hole: this
    // path filed the consultation and rang the doctor without charging for it
    // at all. Only consultations booked for later were ever paid for, so the
    // fastest way to get a free consultation was to ask for one now. Payment
    // carries no `scheduledAt`, which is what tells the flow to go on to
    // matching once it settles rather than to a confirmed appointment.
    if (widget.args.instantOnly) {
      await Navigator.of(context).pushNamed(
        AppRoutes.payment,
        arguments: PaymentArgs(doctor: doctor, mode: mode),
      );
      return;
    }

    await Navigator.of(context).pushNamed(
      AppRoutes.scheduleConsultation,
      arguments: ScheduleConsultationArgs(doctor: doctor, mode: mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

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
                AppTopBar(title: _title),
                // Search and filters stay put while the results scroll.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    sizing.screenPaddingH,
                    0,
                    sizing.screenPaddingH,
                    sizing.spacingMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSearchField(
                        hint: _searchHint,
                        controller: _searchTextController,
                        onChanged: _controller.changeQuery,
                        autofocus: widget.args.searchFirst,
                      ),
                      SizedBox(height: sizing.spacingSm),
                      AppChoiceChips<DoctorListFilter>(
                        options: DoctorListFilter.values,
                        selected: _controller.filter,
                        labelOf: (filter) => filter.label,
                        onSelected: _controller.changeFilter,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _Results(
                    controller: _controller,
                    args: widget.args,
                    onBook: _book,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.controller,
    required this.args,
    required this.onBook,
  });

  final DoctorListController controller;
  final DoctorListArgs args;
  final ValueChanged<Doctor> onBook;

  /// The doctors this listing can actually offer: what the search and chips
  /// left, narrowed to who is free now and who takes the chosen call type.
  List<Doctor> get _bookableDoctors {
    return controller.visibleDoctors.where((doctor) {
      if (args.instantOnly && !doctor.isAvailableNow) return false;
      if (args.mode case final mode? when !doctor.supports(mode)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.errorMessage != null) {
      return _Message(
        icon: Icons.cloud_off_rounded,
        title: controller.errorMessage!,
        actionLabel: 'Retry',
        onAction: controller.load,
      );
    }

    if (controller.isFilteredEmpty) {
      return const _Message(
        icon: Icons.search_off_rounded,
        title: 'No doctors match your search.',
      );
    }

    final doctors = _bookableDoctors;
    if (doctors.isEmpty) {
      return _Message(
        icon: Icons.person_search_rounded,
        title: switch (args.mode) {
          final mode? => tr(
            'No doctor here is taking {mode} calls right now.',
            {'mode': tr(mode.shortLabel).toLowerCase()},
          ),
          null => 'No doctors listed here yet.',
        },
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        0,
        sizing.screenPaddingH,
        sizing.spacingXxl,
      ),
      itemCount: doctors.length,
      separatorBuilder: (_, _) => SizedBox(height: sizing.spacingSm),
      itemBuilder: (context, index) {
        final doctor = doctors[index];

        return DoctorListCard(
          doctor: doctor,
          // An anonymous consult starts the moment the doctor is chosen, so
          // the button says what actually happens.
          actionLabel: args.isAnonymous ? 'Start Consultation' : null,
          onBook: () => onBook(doctor),
          // The card itself opens their profile. The button still books
          // directly for anyone who already knows who they want — a listing
          // where the only way to read about somebody is to book them is a
          // listing that makes the decision for you.
          onTap: () => Navigator.of(context).pushNamed(
            AppRoutes.doctorDetail,
            arguments: DoctorDetailArgs(
              doctor: doctor,
              mode: args.mode,
              anonymousSession: args.anonymousSession,
            ),
          ),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

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
              tr(title),
              style: sizing.text.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: sizing.spacingXs),
              TextButton(
                onPressed: onAction,
                child: Text(tr(actionLabel!), style: sizing.text.sectionAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
