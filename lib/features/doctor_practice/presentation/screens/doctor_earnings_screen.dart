import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_segmented_control.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../profile/presentation/widgets/profile_section.dart';
import '../../domain/entities/doctor_earnings.dart';
import '../controllers/doctor_earnings_controller.dart';
import '../widgets/earnings_chart.dart';

/// Earnings as a standalone route.
///
/// The doctor shell hosts [DoctorEarningsView] directly instead, so the nav bar
/// stays put when Earnings is selected as a tab.
class DoctorEarningsScreen extends StatelessWidget {
  const DoctorEarningsScreen({super.key});

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
        child: DoctorEarningsView(),
      ),
    );
  }
}

/// What the doctor has been paid for.
///
/// **Gross, and it says so on the card.** No commission is deducted anywhere in
/// this app or in the API, because no rate is configured in the project — a
/// percentage invented in code is a number a doctor plans against and is then
/// paid less than. The note is there so the figure is not mistaken for a payout.
///
/// Carries no page shell of its own so it can sit inside one that already
/// exists — nesting `ResponsivePage` would double the Scaffold and SafeArea.
class DoctorEarningsView extends StatefulWidget {
  const DoctorEarningsView({super.key});

  @override
  State<DoctorEarningsView> createState() => _DoctorEarningsViewState();
}

class _DoctorEarningsViewState extends State<DoctorEarningsView> {
  late final DoctorEarningsController _controller =
      sl<DoctorEarningsController>();

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

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTopBar(
          title: 'Earnings',
          variant: AppTopBarVariant.outlined,
          centerTitle: true,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            sizing.screenPaddingH,
            sizing.spacingSm,
            sizing.screenPaddingH,
            sizing.spacingXs,
          ),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => AppSegmentedControl<EarningsPeriod>(
              options: EarningsPeriod.values,
              selected: _controller.period,
              labelOf: (period) => tr(period.label),
              onSelected: _controller.setPeriod,
            ),
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _Body(controller: _controller),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final DoctorEarningsController controller;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    // Only when the read failed outright. A refresh that failed leaves the
    // previous figures on screen under an inline retry — taking the whole
    // screen away because the newest read failed is how a page that loaded
    // fine a minute ago becomes an error page.
    final readError = controller.hasLoaded ? null : controller.errorMessage;
    if (readError != null) {
      return AppErrorView(message: readError, onRetry: controller.load);
    }

    final earnings = controller.earnings;

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
          if (controller.errorMessage case final message?)
            AppInlineError(message: message, onRetry: controller.load),
          _Headline(earnings: earnings),
          SizedBox(height: sizing.spacingLg),
          if (earnings.buckets.isNotEmpty) ...[
            ProfileSection(
              title: 'Over time',
              child: EarningsChart(earnings: earnings),
            ),
            SizedBox(height: sizing.spacingLg),
          ],
          ProfileSection(
            title: 'Consultations',
            child: earnings.entries.isEmpty
                ? const AppEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'Nothing in this period',
                    message: 'Completed consultations appear here.',
                  )
                : ProfileCard(
                    padded: false,
                    children: [
                      for (final (index, entry) in earnings.entries.indexed)
                        _LedgerRow(
                          entry: entry,
                          showDivider: index < earnings.entries.length - 1,
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// The headline figure, with the three numbers that qualify it.
class _Headline extends StatelessWidget {
  const _Headline({required this.earnings});

  final DoctorEarnings earnings;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPaddingLarge),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Billed · {period}', {'period': tr(earnings.period.label)}),
            style: sizing.text.metaLabel.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: sizing.spacingXxs),
          Text(
            earnings.grossLabel,
            style: sizing.text.amountTotal.copyWith(
              fontSize: sizing.sp(32),
              color: AppColors.primaryDeep,
            ),
          ),
          SizedBox(height: sizing.spacingMd),
          Container(height: sizing.hairline, color: AppColors.dividerFaint),
          SizedBox(height: sizing.spacingSm),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: 'Consultations',
                    value: '${earnings.consultations}',
                  ),
                ),
                _Divider(),
                Expanded(
                  child: _Metric(
                    label: 'Average fee',
                    value: earnings.averageFeeLabel,
                  ),
                ),
                _Divider(),
                Expanded(
                  child: _Metric(
                    label: 'In progress',
                    value: '${earnings.inFlight}',
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: sizing.spacingSm),
          Text(
            tr(
              'What patients were charged, before the platform’s share. '
              'Your payout is confirmed when it is sent.',
            ),
            style: sizing.text.legalBody,
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      children: [
        Text(
          value,
          style: sizing.text.amountTotal.copyWith(fontSize: sizing.sp(18)),
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

class _Divider extends StatelessWidget {
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

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.entry, required this.showDivider});

  final EarningsEntry entry;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sizing.cardPadding,
            vertical: sizing.spacingSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.patientName,
                      style: sizing.text.fieldValue.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sizing.spacingXxs / 2),
                    Text(
                      '${entry.whenLabel} · ${entry.detailLabel}',
                      style: sizing.text.metaLabel.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: sizing.spacingXs),
              Text(
                entry.feeLabel,
                style: sizing.text.fieldValue.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.success,
                ),
              ),
            ],
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
