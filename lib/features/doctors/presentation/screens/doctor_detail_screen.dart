import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../anonymous/domain/entities/anonymous_session.dart';
import '../../../consultation/domain/entities/consultation_mode.dart';
import '../../../payment/presentation/screens/payment_screen.dart';
import '../../../consultation/presentation/widgets/consultation_mode_sheet.dart';
import '../../../scheduling/presentation/screens/schedule_consultation_screen.dart';
import '../../domain/entities/doctor.dart';
import '../../../scheduling/domain/entities/doctor_schedule.dart';
import '../../../scheduling/domain/usecases/get_doctor_schedule.dart';
import '../../domain/usecases/get_doctor_profile.dart';
import '../controllers/doctor_detail_controller.dart';
import '../widgets/doctor_reviews.dart';

/// Which doctor to show, and what tapping Consult should do.
class DoctorDetailArgs {
  const DoctorDetailArgs({
    required this.doctor,
    this.mode,
    this.anonymousSession,
  });

  /// The row the listing already had. Everything on it is shown immediately
  /// and the full profile fills in behind.
  final Doctor doctor;

  /// The call type already chosen upstream, when there was one. Null means the
  /// patient is asked here.
  final ConsultationMode? mode;

  /// Set when the patient is consulting under an alias.
  final AnonymousSession? anonymousSession;
}

/// A doctor's profile: who they are, what they charge, and how to reach them.
///
/// **This screen did not exist**, and its absence was the sharpest edge in the
/// patient flow: tapping a doctor on the dashboard filed a consultation and
/// rang them on the spot. There was no way to look at somebody without calling
/// them — so the entire basis for choosing who to discuss your health with was
/// a name, a star and a fee, and a mis-tap was a call to a stranger.
///
/// Tapping a doctor lands here now. Consulting is still one tap away; it is
/// just a tap the patient makes on purpose.
class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({super.key, required this.args});

  final DoctorDetailArgs args;

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  /// Built here rather than resolved whole: the seed row is the screen's to
  /// supply and a locator entry cannot carry it. The use case it wraps still
  /// comes from the graph.
  late final DoctorDetailController _controller = DoctorDetailController(
    sl<GetDoctorProfile>(),
    sl<GetDoctorSchedule>(),
    initial: widget.args.doctor,
  );

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

  /// Asks which kind of consultation this is.
  ///
  /// Always asked here, even when a mode was chosen upstream. Video and audio
  /// are different prices and this profile shows both, so the choice belongs at
  /// the point where it starts costing money — and a mode picked three screens
  /// ago against a different doctor's fees is not a choice anyone remembers
  /// making.
  Future<ConsultationMode?> _chooseMode() =>
      ConsultationModeSheet.show(context, doctor: _controller.doctor);

  /// Rings the doctor now — after paying for it.
  Future<void> _consultNow() async {
    final doctor = _controller.doctor;

    final mode = await _chooseMode();
    if (mode == null || !mounted) return;

    // Through payment rather than straight to matching. An instant
    // consultation used to ring a doctor without charging for it at all, so
    // the only consultations anybody paid for were the booked ones. Payment
    // carries no `scheduledAt`, which is what tells the flow to go on to
    // matching once it settles rather than to a confirmed appointment.
    await Navigator.of(context).pushNamed(
      AppRoutes.payment,
      arguments: PaymentArgs(
        doctor: doctor,
        mode: mode,
        anonymousSession: widget.args.anonymousSession,
      ),
    );
  }

  /// Books a slot instead.
  Future<void> _schedule() async {
    final doctor = _controller.doctor;

    final mode = await _chooseMode();
    if (mode == null || !mounted) return;

    await Navigator.of(context).pushNamed(
      AppRoutes.scheduleConsultation,
      arguments: ScheduleConsultationArgs(doctor: doctor, mode: mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
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
            final doctor = _controller.doctor;

            return Column(
              children: [
                Expanded(child: _Body(controller: _controller)),
                // Pinned rather than scrolled to. The two things this screen
                // exists to make possible must not be below the fold on a
                // profile long enough to be worth reading.
                _ActionBar(
                  doctor: doctor,
                  onConsultNow: _consultNow,
                  onSchedule: _schedule,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final DoctorDetailController controller;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final doctor = controller.doctor;

    return ListView(
      padding: EdgeInsets.only(bottom: sizing.spacingXl),
      children: [
        _Hero(doctor: doctor),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sizing.screenPaddingH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Transform.translate(
                offset: Offset(0, -sizing.spacingLg),
                child: _StatsCard(doctor: doctor),
              ),
              if (controller.errorMessage case final message?) ...[
                AppInlineError(message: message, onRetry: controller.load),
                SizedBox(height: sizing.spacingMd),
              ],
              _FeesCard(doctor: doctor),
              SizedBox(height: sizing.spacingLg),
              // Absent rather than empty while the profile is still coming.
              // A heading called About over a blank card reads as a doctor who
              // wrote nothing about themselves.
              if (doctor.about case final about?) ...[
                _Section(
                  title: 'About',
                  child: Text(
                    about,
                    style: sizing.text.bodySmall.copyWith(height: 1.55),
                  ),
                ),
                SizedBox(height: sizing.spacingLg),
              ] else if (controller.isLoading) ...[
                const _AboutPlaceholder(),
                SizedBox(height: sizing.spacingLg),
              ],
              if (doctor.qualificationsLabel case final qualifications?) ...[
                _Section(
                  title: 'Qualifications',
                  subtitle: qualifications,
                  child: _ChipWrap(values: doctor.qualifications),
                ),
                SizedBox(height: sizing.spacingLg),
              ],
              // The NMC Telemedicine Practice Guidelines require a registered
              // practitioner's council registration number to be shown to the
              // patient. This is the screen they choose from, so it belongs
              // here as well as on the prescription and the receipt.
              if (doctor.registrationNumber case final registration?) ...[
                _Section(
                  title: 'Medical registration',
                  subtitle:
                      'Registered with the National Medical Commission '
                      'or a State Medical Council',
                  child: _ChipWrap(values: [registration]),
                ),
                SizedBox(height: sizing.spacingLg),
              ],
              if (doctor.languages.isNotEmpty) ...[
                _Section(
                  title: 'Speaks',
                  child: _ChipWrap(values: doctor.languages),
                ),
                SizedBox(height: sizing.spacingLg),
              ],
              _Section(
                title: 'Consultation types',
                child: _ModesCard(doctor: doctor),
              ),
              SizedBox(height: sizing.spacingLg),
              // Only once the read has answered. A heading that appears and
              // then changes its mind about what it says is worse than one
              // that arrives a moment late.
              if (controller.schedule != null) ...[
                _Section(
                  title: 'Next available',
                  subtitle: doctor.isAvailableNow
                      ? 'Or consult now, without booking'
                      : null,
                  child: _NextAvailable(controller: controller),
                ),
                SizedBox(height: sizing.spacingLg),
              ],
              // Last on the page, and present whether or not there are any.
              // The star at the top of the screen is an average out of five
              // with nothing behind it; this is what it is an average *of*.
              _Section(
                title: 'Patient reviews',
                subtitle: doctor.reviewSummary,
                child: DoctorReviews(doctor: doctor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// When this doctor is next free, as a row of tappable times.
///
/// The point of the whole section: a doctor who is offline right now is not a
/// dead end, and the profile is where a patient decides. Before this the only
/// answer to "when can I see you" was a Schedule button that opened a grid.
class _NextAvailable extends StatelessWidget {
  const _NextAvailable({required this.controller});

  final DoctorDetailController controller;

  void _book(BuildContext context, OpenSlot slot) {
    Navigator.of(context).pushNamed(
      AppRoutes.scheduleConsultation,
      arguments: ScheduleConsultationArgs(
        doctor: controller.doctor,
        // Carries the chosen time into the booking screen so the tap means
        // something — landing on an unselected grid would throw the choice
        // away and ask it again.
        initialSlot: slot,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final slots = controller.nextOpenSlots;

    if (slots.isEmpty) {
      return Text(
        tr(
          'No open slots in the next few days. '
          'Check back, or try another doctor.',
        ),
        style: sizing.text.bodySmall.copyWith(color: AppColors.textSecondary),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in slots) ...[
          _SlotRow(slot: slot, onTap: () => _book(context, slot)),
          SizedBox(height: sizing.spacingXs),
        ],
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.onTap});

  final OpenSlot slot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(sizing.radiusMd),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: sizing.spacingMd,
          vertical: sizing.spacingSm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(sizing.radiusMd),
          border: Border.all(width: sizing.hairline, color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: sizing.iconXs,
              color: AppColors.primary,
            ),
            SizedBox(width: sizing.spacingSm),
            Expanded(child: Text(slot.label, style: sizing.text.listTitle)),
            Text(
              tr('Book'),
              style: sizing.text.sectionAction.copyWith(
                color: AppColors.primaryDeep,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: sizing.iconSm,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// The banner: photo, name, speciality, and whether they can be reached now.
class _Hero extends StatelessWidget {
  const _Hero({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingXs,
        sizing.screenPaddingH,
        sizing.spacingXxl,
      ),
      decoration: BoxDecoration(
        gradient: AppColors.brandSweep,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(sizing.r(28)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: tr('Back'),
            ),
          ),
          SizedBox(height: sizing.spacingXs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(sizing.r(3)),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: sizing.r(2),
                  ),
                ),
                child: RemoteAvatar(
                  path: doctor.photoUrl,
                  initials: initialsOf(doctor.name),
                  size: sizing.r(72),
                  semanticLabel: doctor.name,
                ),
              ),
              SizedBox(width: sizing.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            doctor.name,
                            style: sizing.text.headline.copyWith(
                              color: Colors.white,
                              fontSize: sizing.sp(20),
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (doctor.isVerified) ...[
                          SizedBox(width: sizing.spacingXxs),
                          Semantics(
                            label: tr('Verified doctor'),
                            child: Icon(
                              Icons.verified_rounded,
                              size: sizing.iconSm,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: sizing.spacingXxs),
                    Text(
                      tr(doctor.speciality),
                      style: sizing.text.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sizing.spacingSm),
                    _AvailabilityPill(isAvailableNow: doctor.isAvailableNow),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `Available now` / `Currently offline` — the one fact that decides whether
/// Consult Now is going to be answered.
class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.isAvailableNow});

  final bool isAvailableNow;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingSm,
        vertical: sizing.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(sizing.radiusPill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: sizing.r(7),
            height: sizing.r(7),
            decoration: BoxDecoration(
              color: isAvailableNow ? const Color(0xFF4ADE80) : Colors.white54,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: sizing.spacingXxs),
          Text(
            isAvailableNow ? tr('Available now') : tr('Currently offline'),
            style: sizing.text.metaLabel.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Experience, rating and how many consultations they have taken.
class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.cardPadding,
        vertical: sizing.spacingMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        boxShadow: AppShadows.card,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Stat(
                icon: Icons.workspace_premium_rounded,
                value: '${doctor.yearsOfExperience}',
                label: 'Years exp.',
                color: AppColors.primary,
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _Stat(
                icon: Icons.star_rounded,
                value: doctor.formattedRating,
                // The count behind the average, because 4.9 from three people
                // and 4.9 from three hundred are different claims.
                label: doctor.reviewCount == 0
                    ? 'Rating'
                    : tr('{count} reviews', {'count': doctor.reviewCount}),
                color: AppColors.warning,
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _Stat(
                icon: Icons.medical_services_rounded,
                value: doctor.consultationsDone == 0
                    ? '—'
                    : '${doctor.consultationsDone}',
                label: 'Consults',
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What each call type costs.
///
/// Both prices, side by side. The listing shows one fee and the doctor may
/// charge less for a voice call — which is what most patients want and had no
/// way of finding out before committing to a mode.
class _FeesCard extends StatelessWidget {
  const _FeesCard({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(
          width: sizing.hairline,
          color: AppColors.consultAccent.border,
        ),
      ),
      child: Row(
        children: [
          if (doctor.supports(ConsultationMode.video))
            Expanded(
              child: _Fee(
                icon: Icons.videocam_rounded,
                label: 'Video',
                amount: doctor.formattedFee,
              ),
            ),
          if (doctor.supports(ConsultationMode.audio))
            Expanded(
              child: _Fee(
                icon: Icons.call_rounded,
                label: 'Voice',
                amount: doctor.formattedAudioFee,
              ),
            ),
        ],
      ),
    );
  }
}

class _Fee extends StatelessWidget {
  const _Fee({required this.icon, required this.label, required this.amount});

  final IconData icon;
  final String label;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: sizing.iconSm, color: AppColors.primaryDeep),
        SizedBox(width: sizing.spacingXs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr(label),
              style: sizing.text.metaLabel.copyWith(
                color: AppColors.primaryDeep,
              ),
            ),
            Text(
              amount,
              style: sizing.text.listTitle.copyWith(
                color: AppColors.primaryDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Which call types this doctor takes, and which they do not.
class _ModesCard extends StatelessWidget {
  const _ModesCard({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          for (final mode in ConsultationMode.values) ...[
            if (mode != ConsultationMode.values.first)
              SizedBox(height: sizing.spacingSm),
            Row(
              children: [
                Icon(
                  iconForConsultationMode(mode),
                  size: sizing.iconSm,
                  color: doctor.supports(mode)
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
                SizedBox(width: sizing.spacingSm),
                Expanded(
                  child: Text(
                    tr(mode.label),
                    style: sizing.text.fieldValue.copyWith(
                      color: doctor.supports(mode)
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ),
                // Said outright rather than left out. A patient who wants a
                // voice call needs to know this doctor does not take them
                // *before* the mode sheet refuses.
                Icon(
                  doctor.supports(mode)
                      ? Icons.check_circle_rounded
                      : Icons.remove_circle_outline_rounded,
                  size: sizing.iconSm,
                  color: doctor.supports(mode)
                      ? AppColors.success
                      : AppColors.textTertiary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The two ways to reach this doctor, pinned to the bottom of the screen.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.doctor,
    required this.onConsultNow,
    required this.onSchedule,
  });

  final Doctor doctor;
  final VoidCallback onConsultNow;
  final VoidCallback onSchedule;

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
        boxShadow: [
          BoxShadow(
            color: Color(0x140C2B2D),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: AppButton.outline(
                label: 'Book a slot',
                onPressed: onSchedule,
              ),
            ),
            SizedBox(width: sizing.spacingSm),
            Expanded(
              child: AppButton.primary(
                label: 'Consult now',
                // Offline means nobody will answer. Offering it anyway is
                // offering a call that times out, which is worse than a
                // disabled button beside a booking that will work.
                onPressed: doctor.isAvailableNow ? onConsultNow : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final Widget child;

  /// Read out in place of the chips by a screen reader, which cannot make
  /// sense of a row of them.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(title).toUpperCase(),
          style: sizing.text.sectionTitle.copyWith(
            fontSize: sizing.sp(13),
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: sizing.spacingXs),
        if (subtitle case final subtitle?)
          Semantics(label: '${tr(title)}: ${tr(subtitle)}', child: child)
        else
          child,
      ],
    );
  }
}

/// A row of small pills — qualifications, languages.
class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Wrap(
      spacing: sizing.spacingXs,
      runSpacing: sizing.spacingXs,
      children: [
        for (final value in values)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: sizing.spacingSm,
              vertical: sizing.spacingXxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(sizing.radiusPill),
              border: Border.all(
                width: sizing.hairline,
                color: AppColors.border,
              ),
            ),
            child: Text(
              tr(value),
              style: sizing.text.metaLabel.copyWith(
                color: AppColors.textLabel,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

/// Three grey bars where the description will be.
///
/// Not a spinner. The rest of the page is already readable, and a spinner in
/// the middle of it reads as the whole screen still loading.
class _AboutPlaceholder extends StatelessWidget {
  const _AboutPlaceholder();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Semantics(
      label: tr('Loading this doctor’s description'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final width in [1.0, 0.95, 0.6]) ...[
            if (width != 1.0) SizedBox(height: sizing.spacingXs),
            FractionallySizedBox(
              widthFactor: width,
              child: Container(
                height: sizing.h(12),
                decoration: BoxDecoration(
                  color: AppColors.dividerFaint,
                  borderRadius: BorderRadius.circular(sizing.radiusXs),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      children: [
        Icon(icon, size: sizing.iconSm, color: color),
        SizedBox(height: sizing.spacingXxs),
        Text(
          value,
          style: sizing.text.amountTotal.copyWith(fontSize: sizing.sp(17)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: sizing.spacingXxs / 2),
        Text(
          tr(label),
          style: sizing.text.metaLabel.copyWith(color: AppColors.textSecondary),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: sizing.hairline,
      margin: EdgeInsets.symmetric(vertical: sizing.spacingXxs),
      color: AppColors.dividerFaint,
    );
  }
}
