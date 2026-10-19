import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/doctor_review.dart';
import '../../domain/usecases/decide_doctor_application.dart';
import '../controllers/admin_queue_controller.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// The administrator's review queue: registrations waiting on a decision.
class AdminQueueScreen extends StatefulWidget {
  const AdminQueueScreen({super.key});

  @override
  State<AdminQueueScreen> createState() => _AdminQueueScreenState();
}

class _AdminQueueScreenState extends State<AdminQueueScreen> {
  late final AdminQueueController _controller = sl<AdminQueueController>();

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

  /// Reports the outcome of a decision or a document that would not open.
  ///
  /// [succeeded] decides the colour, because these two cases used to look
  /// identical: a reviewer approving a doctor and a reviewer whose approval was
  /// refused both got the same grey bar, and the only difference was the
  /// wording.
  void _report(String message, {bool succeeded = false}) {
    if (succeeded) {
      AppSnackBar.success(context, message);
    } else {
      AppSnackBar.error(context, message);
    }
  }

  Future<void> _openCertificate(DoctorReview review) async {
    final url = await _controller.certificateUrl(review.certificatePath!);
    if (!mounted) return;

    if (url == null) {
      _report(_controller.errorMessage ?? 'That certificate could not open.');
      return;
    }

    // External: a signed link to a PDF belongs in the device's own viewer,
    // which handles paging and zoom far better than an in-app web view.
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _report('No app on this device can open that file.');
    }
  }

  Future<void> _approve(DoctorReview review) async {
    final approved = await _controller.approve(review.doctorId);
    if (!mounted) return;

    _report(
      approved
          ? tr('{name} approved.', {'name': review.fullName})
          : _controller.errorMessage ?? 'That could not be saved.',
      succeeded: approved,
    );
  }

  Future<void> _reject(DoctorReview review) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizing.radiusLg),
        ),
      ),
      builder: (_) => _RejectionSheet(doctorName: review.fullName),
    );

    if (reason == null || !mounted) return;

    final rejected = await _controller.reject(review.doctorId, reason);
    if (!mounted) return;

    _report(
      rejected
          ? tr('{name} rejected.', {'name': review.fullName})
          : _controller.errorMessage ?? 'That could not be saved.',
      succeeded: rejected,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      backgroundColor: AppColors.canvas,
      scrollable: false,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppTopBar(
                title: 'Doctor Approvals',
                variant: AppTopBarVariant.outlined,
                centerTitle: true,
              ),
              Expanded(
                child: _Body(controller: _controller, state: this),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.state});

  final AdminQueueController controller;
  final _AdminQueueScreenState state;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.pending.isEmpty) {
      return _EmptyQueue(
        message: controller.errorMessage ?? 'No registrations are waiting.',
        isError: controller.errorMessage != null,
        onRetry: controller.load,
      );
    }

    return AppRefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          sizing.screenPaddingH,
          sizing.spacingLg,
          sizing.screenPaddingH,
          sizing.spacingXxl,
        ),
        itemCount: controller.pending.length,
        separatorBuilder: (_, _) => SizedBox(height: sizing.spacingMd),
        itemBuilder: (context, index) {
          final review = controller.pending[index];

          return _ReviewCard(
            review: review,
            isDeciding: controller.decidingFor == review.doctorId,
            onOpenCertificate: () => state._openCertificate(review),
            onApprove: () => state._approve(review),
            onReject: () => state._reject(review),
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.isDeciding,
    required this.onOpenCertificate,
    required this.onApprove,
    required this.onReject,
  });

  final DoctorReview review;
  final bool isDeciding;
  final VoidCallback onOpenCertificate;
  final VoidCallback onApprove;
  final VoidCallback onReject;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(review.fullName, style: sizing.text.cardTitleLarge),
          SizedBox(height: sizing.spacingXxs),
          Text(tr(review.credentialsLabel), style: sizing.text.cardSubtitle),
          SizedBox(height: sizing.spacingXs),
          _Detail(label: 'Registration', value: review.registrationNumber),
          _Detail(label: 'Practises in', value: tr(review.locationLabel)),
          _Detail(label: 'Phone', value: review.phone),
          _Detail(
            label: 'Submitted',
            value: review.submittedAt == null
                ? null
                : AppDateFormat.monthDayYear(review.submittedAt!),
          ),
          SizedBox(height: sizing.spacingSm),
          if (review.hasCertificate)
            AppButton.outline(
              label: 'View certificate',
              onPressed: isDeciding ? null : onOpenCertificate,
            )
          else
            // Worth stating plainly: the reviewer is deciding on typed details
            // with nothing to check them against.
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: sizing.iconSm,
                  color: AppColors.warning,
                ),
                SizedBox(width: sizing.spacingXs),
                Expanded(
                  child: Text(
                    tr('No certificate uploaded — details entered by hand.'),
                    style: sizing.text.helperText,
                  ),
                ),
              ],
            ),
          SizedBox(height: sizing.spacingMd),
          Row(
            children: [
              Expanded(
                child: AppButton.outline(
                  label: 'Reject',
                  onPressed: isDeciding ? null : onReject,
                ),
              ),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: AppButton.primary(
                  label: 'Approve',
                  isLoading: isDeciding,
                  onPressed: isDeciding ? null : onApprove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.only(top: sizing.spacingXxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: sizing.w(104),
            child: Text(tr(label), style: sizing.text.metaLabel),
          ),
          Expanded(
            child: Text(
              (value ?? '').isEmpty ? tr('Not given') : value!,
              style: sizing.text.cardBody,
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks why, because the database will not accept a rejection without it.
class _RejectionSheet extends StatefulWidget {
  const _RejectionSheet({required this.doctorName});

  final String doctorName;

  @override
  State<_RejectionSheet> createState() => _RejectionSheetState();
}

class _RejectionSheetState extends State<_RejectionSheet> {
  final TextEditingController _reasonController = TextEditingController();
  String _reason = '';

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool get _isLongEnough =>
      _reason.trim().length >= DecideDoctorApplication.minReasonLength;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingXs,
        sizing.screenPaddingH,
        // Clears the keyboard, which this sheet always summons.
        MediaQuery.viewInsetsOf(context).bottom + sizing.spacingLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Reject {name}', {'name': widget.doctorName}),
            style: sizing.text.navTitle,
          ),
          SizedBox(height: sizing.spacingXs),
          Text(
            tr('The doctor sees this, so say what they need to fix.'),
            style: sizing.text.helperText,
          ),
          SizedBox(height: sizing.spacingLg),
          AppTextField(
            label: 'Reason',
            hint: 'e.g. The certificate is not legible — please re-upload it.',
            controller: _reasonController,
            maxLength: 300,
            onChanged: (value) => setState(() => _reason = value),
          ),
          SizedBox(height: sizing.spacingLg),
          AppButton.primary(
            label: 'Send rejection',
            onPressed: _isLongEnough
                ? () => Navigator.of(context).pop(_reason.trim())
                : null,
          ),
        ],
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue({
    required this.message,
    required this.isError,
    required this.onRetry,
  });

  final String message;
  final bool isError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(sizing.screenPaddingH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.inbox_outlined,
              size: sizing.iconLg * 2,
              color: isError ? AppColors.danger : AppColors.textTertiary,
            ),
            SizedBox(height: sizing.spacingMd),
            Text(
              tr(message),
              style: sizing.text.cardBody,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: sizing.spacingLg),
            AppButton.outline(label: 'Refresh', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
