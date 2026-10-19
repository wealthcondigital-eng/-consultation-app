import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../notifications/domain/usecases/announce_appointments.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_segmented_control.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../call/presentation/screens/call_screen.dart';
import '../../../consultation/domain/usecases/answer_consultations.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/usecases/get_appointments.dart';
import '../../presentation/controllers/appointments_controller.dart';
import '../widgets/appointment_card.dart';

/// The appointment history as a standalone route, for either role.
///
/// Both shells host [AppointmentsView] directly instead, so the nav bar stays
/// put when Appointments is selected as a tab.
class AppointmentsScreen extends StatelessWidget {
  const AppointmentsScreen({super.key, required this.audience});

  final AppointmentAudience audience;

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
        child: AppointmentsView(audience: audience),
      ),
    );
  }
}

/// Every consultation, filtered three ways.
///
/// One view for both roles. [audience] decides which endpoint is read and
/// nothing else — the card names whoever is on the *other* end, so a doctor
/// sees patients here and a patient sees doctors, from the same code.
///
/// Carries no page shell of its own so it can sit inside one that already
/// exists — nesting `ResponsivePage` would double the Scaffold and SafeArea.
class AppointmentsView extends StatefulWidget {
  const AppointmentsView({super.key, required this.audience});

  final AppointmentAudience audience;

  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView> {
  /// Built here rather than resolved whole, because the audience is the
  /// screen's to decide and a locator entry cannot carry it. The use case it
  /// wraps still comes from the graph.
  late final AppointmentsController _controller = AppointmentsController(
    sl<GetAppointments>(),
    sl<AnnounceAppointments>(),
    audience: widget.audience,
  );

  /// True while a rejoin is being brokered, so a second tap cannot open two
  /// calls into the same room.
  bool _isJoining = false;

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

  /// Opens a consultation that is still live.
  ///
  /// Through `join` rather than building the call from the row, because `join`
  /// answers with the channel, this device's peer id and which side dials — the
  /// three things a list row does not carry and the app must not guess.
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

      // The call changes the row's status and its duration, so the list is
      // stale the moment it ends.
      if (mounted) await _controller.load();
    } on Failure catch (failure) {
      if (!mounted) return;
      AppSnackBar.error(context, failure.message);
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  /// Opens the receipt for a past consultation.
  ///
  /// The row already holds everything the receipt shows, so this pushes the
  /// entity rather than an id — no fetch, no spinner, and it works offline.
  void _openReceipt(Appointment appointment) {
    Navigator.of(
      context,
    ).pushNamed(AppRoutes.consultationReceipt, arguments: appointment);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: widget.audience == AppointmentAudience.patient
              ? 'My Appointments'
              : 'Consultations',
          variant: AppTopBarVariant.outlined,
          centerTitle: true,
        ),
        // Two controls, two axes. **When** is the expensive question and is
        // asked of the API; **what kind** is a property of rows already in
        // memory and is answered locally. One control mixing the two could not
        // express "my scheduled appointments that have not happened yet",
        // which is the main thing this screen is opened for.
        Padding(
          padding: EdgeInsets.fromLTRB(
            sizing.screenPaddingH,
            sizing.spacingSm,
            sizing.screenPaddingH,
            sizing.spacingXs,
          ),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSegmentedControl<AppointmentFilter>(
                  options: AppointmentFilter.values,
                  selected: _controller.filter,
                  labelOf: (filter) => filter.label,
                  onSelected: _controller.setFilter,
                ),
                SizedBox(height: sizing.spacingSm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _controller.isInitialLoad
                            ? ''
                            : _countLabel(
                                _controller.visibleAppointments.length,
                              ),
                        style: sizing.text.metaLabel.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _KindDropdown(
                      selected: _controller.kind,
                      onSelected: _controller.setKind,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _Body(
              controller: _controller,
              audience: widget.audience,
              onRejoin: _isJoining ? null : _rejoin,
              onViewReceipt: _openReceipt,
            ),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.audience,
    required this.onRejoin,
    required this.onViewReceipt,
  });

  final AppointmentsController controller;
  final AppointmentAudience audience;

  /// Null while a rejoin is already under way, which is what disables every
  /// other row's button rather than only the one that was tapped.
  final ValueChanged<Appointment>? onRejoin;

  /// Opens the fee receipt. Never disabled — it reads what the row already
  /// holds and cannot fail.
  final ValueChanged<Appointment> onViewReceipt;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.isEmpty) {
      // The two emptinesses read differently: nothing at all in this
      // timeframe, versus nothing of the kind that is selected. Saying "no
      // consultations yet" to somebody who has ten instant ones and a
      // Scheduled chip active is simply wrong.
      if (!controller.isTimeframeEmpty) {
        return AppEmptyState(
          icon: Icons.filter_list_off_rounded,
          title: switch (controller.kind) {
            AppointmentKindFilter.scheduled => tr('No scheduled consultations'),
            AppointmentKindFilter.instant => tr('No instant consultations'),
            AppointmentKindFilter.all => tr('No consultations'),
          },
          message: switch (controller.kind) {
            AppointmentKindFilter.scheduled =>
              'Booked appointments will appear here.',
            AppointmentKindFilter.instant =>
              'Consultations started with Consult Now will appear here.',
            AppointmentKindFilter.all => 'Try another filter.',
          },
        );
      }

      return AppEmptyState(
        icon: Icons.event_note_rounded,
        title: switch (controller.filter) {
          AppointmentFilter.upcoming => 'Nothing coming up',
          AppointmentFilter.past => 'No past consultations',
          AppointmentFilter.all => 'No consultations yet',
        },
        message: audience == AppointmentAudience.patient
            ? 'Consultations you book will appear here.'
            : 'Consultations you take will appear here.',
      );
    }

    final groups = controller.groups;

    return AppRefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          sizing.screenPaddingH,
          sizing.spacingXs,
          sizing.screenPaddingH,
          sizing.spacingXxl,
        ),
        children: [
          // Above the rows, not instead of them: a refresh that failed must
          // not take away rows that loaded perfectly well a minute ago.
          if (controller.errorMessage case final message?) ...[
            AppInlineError(message: message, onRetry: controller.load),
            SizedBox(height: sizing.spacingSm),
          ],
          for (final group in groups) ...[
            if (group != groups.first) SizedBox(height: sizing.spacingMd),
            _GroupHeading(group: group),
            SizedBox(height: sizing.spacingXs),
            for (final appointment in group.appointments) ...[
              if (appointment != group.appointments.first)
                SizedBox(height: sizing.spacingSm),
              _card(appointment),
            ],
          ],
        ],
      ),
    );
  }

  Widget _card(Appointment appointment) {
    final onRejoin = this.onRejoin;

    return AppointmentCard(
      appointment: appointment,
      onRejoin: onRejoin == null ? null : () => onRejoin(appointment),
      onViewReceipt: () => onViewReceipt(appointment),
    );
  }
}

/// `1 consultation` / `3 consultations`.
String _countLabel(int count) => count == 1
    ? tr('{count} consultation', {'count': count})
    : tr('{count} consultations', {'count': count});

/// `Today · 3 consultations` — the heading over one day's rows.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.group});

  final AppointmentGroup group;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final count = group.appointments.length;
    final isToday = AppDateFormat.isSameDay(group.date, DateTime.now());

    return Row(
      children: [
        Container(
          width: sizing.r(6),
          height: sizing.r(6),
          decoration: BoxDecoration(
            // Today is the one being acted on; the rest are information.
            color: isToday ? AppColors.primary : AppColors.textTertiary,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Flexible(
          child: Text(
            group.label,
            style: sizing.text.cardTitle.copyWith(fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Expanded(
          child: Text(
            _countLabel(count),
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

/// Instant, scheduled or both — a compact dropdown rather than a row of chips,
/// so the list itself starts higher on the screen.
class _KindDropdown extends StatelessWidget {
  const _KindDropdown({required this.selected, required this.onSelected});

  final AppointmentKindFilter selected;
  final ValueChanged<AppointmentKindFilter> onSelected;

  static IconData _iconOf(AppointmentKindFilter kind) => switch (kind) {
    AppointmentKindFilter.all => Icons.tune_rounded,
    AppointmentKindFilter.instant => Icons.bolt_rounded,
    AppointmentKindFilter.scheduled => Icons.event_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final isFiltered = selected != AppointmentKindFilter.all;

    return PopupMenuButton<AppointmentKindFilter>(
      initialValue: selected,
      onSelected: onSelected,
      tooltip: tr('Consultation type'),
      position: PopupMenuPosition.under,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(sizing.radiusMd),
      ),
      itemBuilder: (context) => [
        for (final kind in AppointmentKindFilter.values)
          PopupMenuItem<AppointmentKindFilter>(
            value: kind,
            height: sizing.buttonHeightCompact,
            child: Row(
              children: [
                Icon(
                  _iconOf(kind),
                  size: sizing.iconSm,
                  color: kind == selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                SizedBox(width: sizing.spacingSm),
                Expanded(
                  child: Text(
                    tr(kind.label),
                    style: sizing.text.fieldValue.copyWith(
                      color: kind == selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: kind == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (kind == selected)
                  Icon(
                    Icons.check_rounded,
                    size: sizing.iconSm,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: sizing.spacingSm,
          vertical: sizing.spacingXs,
        ),
        decoration: BoxDecoration(
          color: isFiltered ? AppColors.primarySurface : AppColors.surface,
          borderRadius: BorderRadius.circular(sizing.radiusMd),
          border: Border.all(
            width: sizing.hairline,
            color: isFiltered ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconOf(selected),
              size: sizing.iconXs,
              color: isFiltered ? AppColors.primary : AppColors.textSecondary,
            ),
            SizedBox(width: sizing.spacingXxs),
            Text(
              tr(selected.label),
              style: sizing.text.metaLabel.copyWith(
                color: isFiltered ? AppColors.primaryDeep : AppColors.textLabel,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(width: sizing.spacingXxs),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: sizing.iconSm,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
