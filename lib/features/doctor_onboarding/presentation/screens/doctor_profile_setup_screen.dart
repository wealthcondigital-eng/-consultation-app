import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_confirm_dialog.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../auth/domain/usecases/sign_out.dart';
import '../../../onboarding/domain/entities/user_role.dart';
import '../../data/datasources/certificate_picker.dart';
import '../../domain/entities/doctor_application.dart';
import '../../domain/entities/doctor_setup_step.dart';
import '../../domain/entities/medical_certificate.dart';
import '../controllers/doctor_setup_controller.dart';
import '../widgets/bank_step.dart';
import '../widgets/details_step.dart';
import '../widgets/setup_stepper.dart';
import '../widgets/upload_step.dart';
import '../../../../core/l10n/tr.dart';

/// Doctor profile setup: upload and verify, then details, then the payout
/// account.
///
/// One screen for all three steps — they share the certificate and its parsed
/// values, and the stepper has to stay put between them.
class DoctorProfileSetupScreen extends StatefulWidget {
  const DoctorProfileSetupScreen({super.key});

  @override
  State<DoctorProfileSetupScreen> createState() =>
      _DoctorProfileSetupScreenState();
}

class _DoctorProfileSetupScreenState extends State<DoctorProfileSetupScreen> {
  late final DoctorSetupController _controller = sl<DoctorSetupController>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _registrationController = TextEditingController();
  final BankFieldControllers _bankControllers = BankFieldControllers();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncParsedFields);
    _controller.loadOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _registrationController.dispose();
    _bankControllers.dispose();
    _controller
      ..removeListener(_syncParsedFields)
      ..dispose();
    super.dispose();
  }

  /// Puts what the certificate gave us into the text fields. Only fills a field
  /// the doctor has not typed in, so their own entry is never overwritten.
  void _syncParsedFields() {
    final credentials = _controller.credentials;

    if (_nameController.text.isEmpty && credentials.fullName.isNotEmpty) {
      _nameController.text = credentials.fullName;
    }
    if (_registrationController.text.isEmpty &&
        credentials.registrationNumber.isNotEmpty) {
      _registrationController.text = credentials.registrationNumber;
    }
  }

  Future<void> _pickCertificate(CertificateSource source) async {
    final certificate = await sl<CertificatePicker>().pick(source);
    if (!mounted || certificate == null) return;

    final uploaded = await _controller.uploadCertificate(certificate);
    if (!mounted) return;

    if (!uploaded) {
      _showError();
      return;
    }

    // No snackbar. The screen moves to the next step and the banner there says
    // the certificate was received — a bar over the top of both would be the
    // same news told three times.
    //
    // The parse filled the form in, so the doctor lands on it to check.
    _controller.goToNextStep();
  }

  /// Continue from the upload step.
  ///
  /// A separate handler rather than `goToNextStep` passed straight through, so
  /// a press with nothing uploaded surfaces the controller's explanation
  /// instead of doing nothing visible.
  void _continueFromUpload() {
    if (_controller.goToNextStep()) return;
    _showError();
  }

  void _showError() {
    final message = _controller.errorMessage;
    if (message == null) return;

    AppSnackBar.error(context, message);
  }

  /// Back walks the steps, and from the first one leaves the registration.
  ///
  /// Leaving used to be `maybePop()`, which did **nothing** here: this screen
  /// is reached with `pushNamedAndRemoveUntil(..., (route) => false)`, so there
  /// is no route underneath to pop to — the back button appeared dead, and the
  /// system gesture closed the app instead. A doctor who opened registration by
  /// mistake had no way out but killing it.
  ///
  /// The way out is the login screen, which is where "start again" means
  /// something. The session goes with it: a half-filed registration left signed
  /// in would drop them straight back here on the next launch.
  Future<void> _back() async {
    if (_controller.goToPreviousStep()) return;

    final leave = await AppConfirmDialog.show(
      context,
      title: 'Leave registration?',
      message:
          'Your certificate and details have not been submitted yet. '
          'You will be signed out and can start again from login.',
      confirmLabel: 'Leave and sign out',
      cancelLabel: 'Keep registering',
      icon: Icons.logout_rounded,
      tone: AppConfirmTone.destructive,
    );

    if (!leave || !mounted) return;

    final navigator = Navigator.of(context);

    try {
      await sl<SignOut>()();
    } catch (_) {
      // The local token is cleared either way, and they are leaving regardless.
    }

    // The whole stack goes: an abandoned registration is not something to come
    // back to with the back gesture.
    await navigator.pushNamedAndRemoveUntil(
      AppRoutes.phoneLogin,
      (route) => false,
      arguments: UserRole.doctor,
    );
  }

  Future<void> _submit() async {
    final application = await _controller.submit();
    if (!mounted) return;

    if (application == null) {
      _showError();
      return;
    }

    await _openReview(application);
  }

  Future<void> _openReview(DoctorApplication application) async {
    // Registration is done: the form behind this is not worth returning to.
    await Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.doctorApplicationPending,
      (route) => false,
      arguments: application,
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
      // The system back gesture is routed through the same handler as the
      // button. Without this it reached the navigator, found nothing below
      // this route — it is pushed with `(route) => false` — and closed the app
      // instead of stepping back through the form.
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: ResponsivePage(
          backgroundColor: AppColors.canvas,
          scrollable: false,
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final step = _controller.step;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTopBar(
                    title: 'Doctor Profile Setup',
                    variant: AppTopBarVariant.outlined,
                    onBack: _back,
                    // No Skip. The certificate is what a reviewer decides on, so
                    // there is nothing to skip *to* — see [UploadStep].
                  ),
                  SetupStepper(current: step, isDone: _controller.isStepDone),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        sizing.screenPaddingH,
                        sizing.spacingLg,
                        sizing.screenPaddingH,
                        sizing.spacingXl,
                      ),
                      children: [
                        Text(tr(step.title), style: sizing.text.headline),
                        SizedBox(height: sizing.spacingLg),
                        switch (step) {
                          DoctorSetupStep.uploadVerify => UploadStep(
                            controller: _controller,
                            onPick: _pickCertificate,
                            onContinue: _continueFromUpload,
                          ),
                          DoctorSetupStep.details => DetailsStep(
                            controller: _controller,
                            nameController: _nameController,
                            registrationController: _registrationController,
                          ),
                          DoctorSetupStep.bank => BankStep(
                            controller: _controller,
                            controllers: _bankControllers,
                          ),
                        },
                        if (step != DoctorSetupStep.uploadVerify) ...[
                          SizedBox(height: sizing.spacingXxl),
                          AppButton.emphasis(
                            label: step == DoctorSetupStep.details
                                ? 'Continue to Bank Details'
                                : 'Complete Registration',
                            isLoading: _controller.isSubmitting,
                            onPressed: step == DoctorSetupStep.details
                                ? _controller.goToNextStep
                                : _submit,
                          ),
                        ],
                      ],
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
