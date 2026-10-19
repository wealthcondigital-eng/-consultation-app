import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/media/medical_report_picker.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/document_viewer_screen.dart';
import '../../domain/entities/medical_report.dart';
import '../controllers/medical_reports_controller.dart';

/// The documents on a patient's record: lab results, scans, prescriptions.
///
/// Sits under the typed history rather than beside it, because the two are read
/// in that order — a doctor scans the summary and opens a report only when a
/// line of it needs backing up.
///
/// Adding is three taps at most, and the first is a camera: a patient with a
/// printed result in their hand is the common case by a distance, and a flow
/// that opens a file browser first makes them go and photograph it themselves
/// before they can start.
class MedicalReportsSection extends StatefulWidget {
  const MedicalReportsSection({super.key});

  @override
  State<MedicalReportsSection> createState() => _MedicalReportsSectionState();
}

class _MedicalReportsSectionState extends State<MedicalReportsSection> {
  late final MedicalReportsController _controller =
      sl<MedicalReportsController>();

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

  Future<void> _add() async {
    // What it is, before where it comes from. The kind changes how a doctor
    // reads the row and the patient is the only one who knows it; asking after
    // the file is chosen would mean a question about a document they have
    // already stopped thinking about.
    final kind = await showModalBottomSheet<MedicalRecordKind>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizing.radiusXl),
        ),
      ),
      builder: (_) => const _KindSheet(),
    );

    if (kind == null || !mounted) return;

    final source = await showModalBottomSheet<ReportSource>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.sizing.radiusXl),
        ),
      ),
      builder: (_) => _SourceSheet(kind: kind),
    );

    if (source == null || !mounted) return;

    final picked = await sl<MedicalReportPicker>().pick(source);
    if (picked == null || !mounted) return;

    // The file's own name, which the API keeps when no title is given. A prompt
    // for a title here would put a text field between a patient and the one
    // thing they came to do; renaming can come later, and mostly will not.
    final added = await _controller.add(filePath: picked.localPath, kind: kind);

    if (added && mounted) {
      AppSnackBar.success(context, switch (kind) {
        MedicalRecordKind.prescription => tr(
          'Prescription added to your record.',
        ),
        MedicalRecordKind.report => tr('Report added to your record.'),
      });
    }
  }

  Future<void> _remove(MedicalReport report) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Remove this report?',
      message: tr(
        '{title} will be deleted from your record. Doctors you consult will '
        'no longer see it.',
        {'title': report.title},
      ),
      confirmLabel: 'Remove',
      icon: Icons.delete_outline_rounded,
      tone: AppConfirmTone.destructive,
    );

    if (confirmed) await _controller.remove(report);
  }

  void _open(MedicalReport report) {
    Navigator.of(context).pushNamed(
      AppRoutes.documentViewer,
      arguments: DocumentViewerArgs(
        title: report.title,
        subtitle: '${report.fileName} · ${report.sizeLabel}',
        path: report.filePath,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Medical records'),
                    style: sizing.text.sectionTitle,
                  ),
                ),
                TextButton.icon(
                  onPressed: _controller.isUploading ? null : _add,
                  icon: _controller.isUploading
                      ? SizedBox.square(
                          dimension: sizing.iconXs,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.add_rounded, size: sizing.iconSm),
                  label: Text(
                    _controller.isUploading ? tr('Adding…') : tr('Add'),
                    style: sizing.text.sectionAction,
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            SizedBox(height: sizing.spacingXs),
            if (_controller.isInitialLoad)
              Padding(
                padding: EdgeInsets.symmetric(vertical: sizing.spacingMd),
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (_controller.items.isEmpty)
              _Empty(onAdd: _controller.isUploading ? null : _add)
            else
              // Prescriptions first, under their own heading. A doctor opening
              // this in the first minute of a call is looking for what the
              // patient is taking, and a scan from two years ago sitting above
              // it is a scan they have to scroll past.
              for (final kind in MedicalRecordKind.values)
                if (_controller.items.where((r) => r.kind == kind)
                    case final group when group.isNotEmpty) ...[
                  SizedBox(height: sizing.spacingXs),
                  Text(tr(kind.sectionTitle), style: sizing.text.metaLabel),
                  SizedBox(height: sizing.spacingXs),
                  for (final report in group) ...[
                    if (report != group.first)
                      SizedBox(height: sizing.spacingXs),
                    _ReportRow(
                      report: report,
                      onOpen: () => _open(report),
                      onRemove: () => _remove(report),
                    ),
                  ],
                ],
          ],
        );
      },
    );
  }
}

/// Prescription or report.
///
/// Two plain choices with no verification language on either. A patient
/// photographing a printout from any clinic and a doctor issuing one here both
/// land on the record as prescriptions; nothing marks one as approved, because
/// nothing here is in a position to judge that.
class _KindSheet extends StatelessWidget {
  const _KindSheet();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          sizing.screenPaddingH,
          0,
          sizing.screenPaddingH,
          sizing.spacingMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('What are you adding?'), style: sizing.text.sectionTitle),
            SizedBox(height: sizing.spacingXxs),
            Text(
              tr('Your doctor sees both during a consultation.'),
              style: sizing.text.cardSubtitle,
            ),
            SizedBox(height: sizing.spacingMd),
            _KindRow(
              icon: Icons.medication_rounded,
              label: 'Prescription',
              note: 'Medicines a doctor has prescribed you',
              kind: MedicalRecordKind.prescription,
            ),
            _KindRow(
              icon: Icons.description_rounded,
              label: 'Report or document',
              note: 'A lab result, a scan, a discharge summary',
              kind: MedicalRecordKind.report,
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _KindRow extends StatelessWidget {
  const _KindRow({
    required this.icon,
    required this.label,
    required this.note,
    required this.kind,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String note;
  final MedicalRecordKind kind;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(kind),
          borderRadius: BorderRadius.circular(sizing.radiusMd),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: sizing.spacingSm),
            child: Row(
              children: [
                Icon(icon, size: sizing.iconMd, color: AppColors.primary),
                SizedBox(width: sizing.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(label), style: sizing.text.cardTitle),
                      Text(tr(note), style: sizing.text.cardSubtitle),
                    ],
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
        ),
        if (showDivider) Divider(height: 1, color: AppColors.border),
      ],
    );
  }
}

/// Where a report comes from. Camera first, because that is what most of them
/// are: a printed result held under a lamp.
class _SourceSheet extends StatelessWidget {
  const _SourceSheet({required this.kind});

  final MedicalRecordKind kind;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          sizing.screenPaddingH,
          0,
          sizing.screenPaddingH,
          sizing.spacingMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(switch (kind) {
              MedicalRecordKind.prescription => tr('Add a prescription'),
              MedicalRecordKind.report => tr('Add a report'),
            }, style: sizing.text.sectionTitle),
            SizedBox(height: sizing.spacingXxs),
            Text(switch (kind) {
              MedicalRecordKind.prescription => tr(
                'A photo of the printout, or the PDF a doctor sent you.',
              ),
              MedicalRecordKind.report => tr(
                'A lab result, a scan, or a discharge summary.',
              ),
            }, style: sizing.text.cardSubtitle),
            SizedBox(height: sizing.spacingMd),
            _SourceRow(
              icon: Icons.photo_camera_rounded,
              label: 'Take a photo',
              note: 'Hold the page flat and fill the frame',
              source: ReportSource.camera,
            ),
            _SourceRow(
              icon: Icons.photo_library_rounded,
              label: 'Choose from gallery',
              note: 'A photo you have already taken',
              source: ReportSource.gallery,
            ),
            _SourceRow(
              icon: Icons.attach_file_rounded,
              label: 'Choose a file',
              note: 'A PDF your lab or hospital sent you',
              source: ReportSource.file,
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.note,
    required this.source,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String note;
  final ReportSource source;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      children: [
        InkWell(
          onTap: () => Navigator.of(context).pop(source),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: sizing.spacingSm),
            child: Row(
              children: [
                Container(
                  width: sizing.iconChipSize * 0.75,
                  height: sizing.iconChipSize * 0.75,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(sizing.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    size: sizing.iconSm,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: sizing.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(label), style: sizing.text.cardTitle),
                      SizedBox(height: sizing.spacingXxs * 0.5),
                      Text(tr(note), style: sizing.text.metaLabel),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Container(height: sizing.hairline, color: AppColors.dividerFaint),
      ],
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.report,
    required this.onOpen,
    required this.onRemove,
  });

  final MedicalReport report;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        child: Padding(
          padding: EdgeInsets.all(sizing.cardPadding),
          child: Row(
            children: [
              Container(
                width: sizing.iconChipSize * 0.75,
                height: sizing.iconChipSize * 0.75,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(sizing.radiusSm),
                ),
                child: Icon(
                  // The glyph says which viewer opens, which is the one thing
                  // a row of similarly-named scans does not otherwise tell you.
                  report.isPdf
                      ? Icons.picture_as_pdf_rounded
                      : Icons.image_rounded,
                  size: sizing.iconSm,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(width: sizing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: sizing.text.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: sizing.spacingXxs * 0.5),
                    // This section lives on the patient's own profile, so the
                    // authorship reads from their end.
                    Text(
                      report.detailLabelFor(asDoctor: false),
                      style: sizing.text.metaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.delete_outline_rounded, size: sizing.iconSm),
                color: AppColors.textTertiary,
                visualDensity: VisualDensity.compact,
                tooltip: tr('Remove'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nothing uploaded yet.
///
/// Says what a report is *for* rather than that the list is empty. A patient
/// who has never uploaded one does not know whether this is a filing cabinet
/// for their own benefit or something the doctor will actually read.
class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return DottedBorderBox(
      onTap: onAdd,
      child: Column(
        children: [
          Icon(
            Icons.upload_file_rounded,
            size: sizing.r(28),
            color: AppColors.primary,
          ),
          SizedBox(height: sizing.spacingXs),
          Text(
            tr('Add a lab result or scan'),
            style: sizing.text.cardTitle,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: sizing.spacingXxs),
          Text(
            tr(
              'The doctor can open it during your consultation, so you do not '
              'have to read numbers out.',
            ),
            style: sizing.text.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// A dashed panel that reads as a drop target.
///
/// Dashed rather than solid on purpose: a solid card at this size looks like
/// content that failed to load, where a dashed one reads as a space waiting to
/// be filled.
class DottedBorderBox extends StatelessWidget {
  const DottedBorderBox({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(sizing.radiusLg),
      child: CustomPaint(
        painter: _DashedBorderPainter(radius: sizing.radiusLg),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sizing.cardPadding,
            vertical: sizing.spacingLg,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    // Walked as a path rather than drawn as four dashed lines, so the dashes
    // carry on round the corners instead of stopping at them.
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 6), paint);
        distance += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.radius != radius;
}
