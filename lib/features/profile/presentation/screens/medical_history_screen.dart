import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_note_field.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/medical_history.dart';
import '../../domain/usecases/manage_medical_history.dart';
import '../controllers/medical_history_controller.dart';
import '../widgets/medical_reports_section.dart';
import '../widgets/profile_section.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// The patient's own account of their health.
///
/// Four chip lists and a note. Chips rather than a paragraph, because the
/// doctor reads this in the first thirty seconds of a consultation and a wall
/// of prose is not read at all — and because "Penicillin" as its own entry can
/// be picked out at a glance, where "allergic to penicillin, I think" cannot.
///
/// Pops back the saved record, so the profile screen behind can fold it in
/// rather than re-reading a page the app just wrote.
class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key});

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  late final MedicalHistoryController _controller =
      sl<MedicalHistoryController>();

  /// The notes field's own controller. Seeded once, after the record loads —
  /// re-seeding it on every rebuild would move the caret to the end while
  /// someone was typing in the middle.
  final TextEditingController _notes = TextEditingController();
  bool _notesSeeded = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onChanged)
      ..load();
  }

  @override
  void dispose() {
    _notes.dispose();
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;

    if (!_notesSeeded && !_controller.isInitialLoad) {
      _notesSeeded = true;
      _notes.text = _controller.history.notes ?? '';
    }

    final message = _controller.errorMessage;
    if (message == null) return;

    _controller.acknowledgeError();
    AppSnackBar.error(context, message);
  }

  Future<void> _save() async {
    final saved = await _controller.save();
    if (saved == null || !mounted) return;

    Navigator.of(context).pop(saved);
  }

  /// Closes the screen, asking first when there is an unsaved edit.
  ///
  /// A medical record is a tedious thing to type, and losing it to a stray
  /// back-swipe is the kind of loss somebody does not come back and redo.
  Future<void> _close() async {
    if (!_controller.isDirty) {
      Navigator.of(context).pop();
      return;
    }

    final navigator = Navigator.of(context);
    final sizing = context.sizing;

    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('Discard changes?'), style: sizing.text.cardTitleLarge),
        content: Text(
          tr('Your medical record has unsaved changes.'),
          style: sizing.text.helperText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Keep editing'), style: sizing.text.sectionAction),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              tr('Discard'),
              style: sizing.text.sectionAction.copyWith(
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );

    // The navigator was captured before the await, so no `BuildContext` is
    // read after it.
    if (discard == true) navigator.pop();
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
      child: PopScope(
        // Intercepted rather than blocked: the pop is stopped, the question is
        // asked, and `_close` pops for real on a yes.
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: ResponsivePage(
          backgroundColor: AppColors.canvas,
          scrollable: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTopBar(
                    title: 'Medical Records',
                    variant: AppTopBarVariant.outlined,
                    onBack: _close,
                  ),
                  Expanded(
                    child: _Body(controller: _controller, notes: _notes),
                  ),
                  if (!_controller.isInitialLoad)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        sizing.screenPaddingH,
                        sizing.spacingXs,
                        sizing.screenPaddingH,
                        sizing.spacingMd,
                      ),
                      child: AppButton.primary(
                        label: 'Save record',
                        onPressed: _controller.canSave ? _save : null,
                        isLoading: _controller.isSaving,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller, required this.notes});

  final MedicalHistoryController controller;
  final TextEditingController notes;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    final history = controller.history;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingSm,
        sizing.screenPaddingH,
        sizing.spacingXl,
      ),
      children: [
        _Intro(history: history),
        SizedBox(height: sizing.spacingLg),
        // First, because it is what a doctor actually reads: a prescription
        // or a lab report says what the condition is in terms they trust, and
        // the typed lists of conditions, medication, allergies and procedures
        // that used to sit above it only restated that less reliably. Those
        // lists are gone from the form; anything they held is still on the
        // record and is saved back untouched.
        //
        // Saves on its own rather than with the rest of the form — an upload
        // that waited for Save would be lost by a back gesture, and a patient
        // who has just photographed a result expects it to be kept.
        const MedicalReportsSection(),
        SizedBox(height: sizing.spacingLg),
        ProfileSection(
          title: 'Note for your doctor',
          child: AppNoteField(
            label: 'Notes',
            hint:
                'Optional — e.g. a drug allergy, or a medicine you take daily.',
            controller: notes,
            maxLength: ManageMedicalHistory.maxNotesLength,
            onChanged: controller.setNotes,
          ),
        ),
      ],
    );
  }
}

/// What this record is for, said once at the top.
///
/// Worth the space: a patient asked for their conditions without being told who
/// reads them will either leave it blank or over-share. It names the audience,
/// and it names the length.
class _Intro extends StatelessWidget {
  const _Intro({required this.history});

  final MedicalHistory history;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.infoSurface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(
          width: sizing.hairline,
          color: AppColors.consultAccent.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.medical_information_rounded,
                size: sizing.iconSm,
                color: AppColors.primaryVivid,
              ),
              SizedBox(width: sizing.spacingXs),
              Expanded(
                child: Text(
                  tr('Shared with the doctor you consult'),
                  style: sizing.text.cardTitle.copyWith(
                    color: AppColors.primaryVivid,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: sizing.spacingXs),
          Text(
            tr(
              'Upload your prescriptions, lab reports and scans. Only a doctor '
              'in a consultation with you can see them.',
            ),
            style: sizing.text.legalBody,
          ),
        ],
      ),
    );
  }
}
