import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../doctor_onboarding/domain/entities/medical_certificate.dart';
import '../controllers/doctor_credentials_controller.dart';

/// Adds one certificate to the doctor's own profile.
///
/// A sheet rather than a screen because it is two fields and a button, and
/// because it opens over the list it adds to — the doctor watches the row
/// appear where they expected it.
///
/// **The title and the file are collected together.** A title with no document
/// behind it is a claim nobody checked, which is exactly what the review exists
/// to prevent, so neither is submittable without the other. What the doctor
/// types here is the sentence patients read once a reviewer accepts it; the
/// file itself never leaves the private bucket.
class AddCertificateSheet extends StatefulWidget {
  const AddCertificateSheet({super.key, required this.controller});

  final DoctorCredentialsController controller;

  /// Returns true when a certificate was filed.
  static Future<bool> show(
    BuildContext context, {
    required DoctorCredentialsController controller,
  }) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => AddCertificateSheet(controller: controller),
    );

    return added ?? false;
  }

  @override
  State<AddCertificateSheet> createState() => _AddCertificateSheetState();
}

class _AddCertificateSheetState extends State<AddCertificateSheet> {
  final TextEditingController _title = TextEditingController();

  DoctorCredentialsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    // Anything left over from a sheet that was opened and abandoned. Starting
    // with somebody else's file already attached is worse than starting empty.
    _controller.clearPendingFile();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pick(CertificateSource source) async {
    await _controller.pickFile(source);
    if (!mounted) return;

    // The picker reports its own refusals through the controller, which the
    // sheet renders inline — a snackbar behind a modal is a message nobody
    // reads.
    setState(() {});
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final added = await _controller.addCertificate(_title.text);
    if (!mounted) return;

    if (!added) {
      setState(() {});
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      // Lifts the sheet clear of the keyboard, which otherwise covers the very
      // field it was opened for.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final file = _controller.pendingFile;
            final canSubmit =
                file != null &&
                _title.text.trim().length >= 2 &&
                !_controller.isSaving;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                sizing.screenPaddingH,
                sizing.spacingMd,
                sizing.screenPaddingH,
                sizing.spacingLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: sizing.w(44),
                      height: sizing.h(4),
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(sizing.radiusPill),
                      ),
                    ),
                  ),
                  SizedBox(height: sizing.spacingMd),
                  Text(tr('Add a certificate'), style: sizing.text.screenTitle),
                  SizedBox(height: sizing.spacingXs),
                  Text(
                    tr(
                      'A reviewer checks the document against what you call it. '
                      'It appears on your profile once they accept it.',
                    ),
                    style: sizing.text.helperText,
                  ),
                  SizedBox(height: sizing.spacingLg),
                  AppTextField(
                    label: 'What is it?',
                    hint: 'Fellowship in Interventional Cardiology',
                    controller: _title,
                    maxLength: 120,
                    onChanged: (_) => setState(() {}),
                  ),
                  SizedBox(height: sizing.spacingMd),
                  if (file == null)
                    _PickRow(
                      onScan: () => _pick(CertificateSource.scan),
                      onBrowse: () => _pick(CertificateSource.gallery),
                    )
                  else
                    _PickedFile(
                      file: file,
                      onClear: () {
                        _controller.clearPendingFile();
                        setState(() {});
                      },
                    ),
                  if (_controller.errorMessage case final message?) ...[
                    SizedBox(height: sizing.spacingSm),
                    Text(tr(message), style: sizing.text.error),
                  ],
                  SizedBox(height: sizing.spacingLg),
                  AppButton.primary(
                    label: _controller.isSaving
                        ? 'Sending…'
                        : 'Send for review',
                    onPressed: canSubmit ? _submit : null,
                  ),
                  if (!canSubmit && !_controller.isSaving) ...[
                    SizedBox(height: sizing.spacingXs),
                    Text(
                      // Says what unlocks the button rather than leaving a dead
                      // control to be poked at.
                      tr(
                        file == null
                            ? 'Attach the document to continue.'
                            : 'Give the certificate a name to continue.',
                      ),
                      style: sizing.text.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PickRow extends StatelessWidget {
  const _PickRow({required this.onScan, required this.onBrowse});

  final VoidCallback onScan;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      children: [
        Expanded(
          child: AppButton.outline(
            label: 'Scan',
            leading: const Icon(Icons.photo_camera_rounded),
            onPressed: onScan,
          ),
        ),
        SizedBox(width: sizing.spacingSm),
        Expanded(
          child: AppButton.outline(
            label: 'Browse',
            leading: const Icon(Icons.folder_open_rounded),
            onPressed: onBrowse,
          ),
        ),
      ],
    );
  }
}

class _PickedFile extends StatelessWidget {
  const _PickedFile({required this.file, required this.onClear});

  final MedicalCertificate file;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusMd),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_rounded,
            size: sizing.iconSm,
            color: AppColors.primaryVivid,
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.fileName,
                  style: sizing.text.fieldValue,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(file.sizeLabel, style: sizing.text.caption),
              ],
            ),
          ),
          IconButton(
            onPressed: onClear,
            tooltip: tr('Remove'),
            iconSize: sizing.iconSm,
            icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
