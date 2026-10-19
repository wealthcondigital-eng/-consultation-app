import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_wheel_sheet.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../onboarding/domain/entities/user_role.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/patient_profile.dart';
import '../controllers/complete_profile_controller.dart';
import '../widgets/compliance_footer.dart';
import '../widgets/consent_section.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Step four of onboarding: the details needed before a first consultation.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key, this.role});

  final UserRole? role;

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  late final CompleteProfileController _controller =
      sl<CompleteProfileController>();

  final TextEditingController _nameTextController = TextEditingController();

  @override
  void dispose() {
    _nameTextController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();

    // Opens on the youngest date that is still eligible, so an adult scrolls
    // back a little and a minor cannot land on a valid date by doing nothing.
    final eligibleFrom = DateTime(
      now.year - PatientProfile.minAgeYears,
      now.month,
      now.day,
    );

    final selected = await AppDateWheelSheet.show(
      context,
      initial: _controller.dateOfBirth ?? eligibleFrom,
      firstDate: DateTime(now.year - PatientProfile.maxAgeYears),
      lastDate: now,
      title: 'Date of birth',
    );

    if (selected != null) _controller.changeDateOfBirth(selected);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final outcome = await _controller.submit();
    if (!mounted) return;

    switch (outcome) {
      case CompleteProfileOutcome.saved:
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (route) => false,
          arguments: widget.role,
        );
      case CompleteProfileOutcome.underage:
        await _showUnderageDialog();
      case CompleteProfileOutcome.invalid:
        // The inline field errors already explain it.
        break;
      case CompleteProfileOutcome.failed:
        final message = _controller.errorMessage;
        if (message != null) AppSnackBar.error(context, message);
    }
  }

  /// Explains the 18+ rule and offers the way a minor actually gets seen.
  ///
  /// A dialog rather than a red line under the field: this ends the sign-up
  /// instead of asking for a correction, and it has to say what to do next.
  /// Nothing is submitted and nothing is blocked — the date stays on the form
  /// so a mistyped year is one tap from being fixed.
  Future<void> _showUnderageDialog() {
    final age = _controller.age;

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('You need to be 18 or older')),
        content: Text(
          age == null
              ? tr(
                  'An account on this app can only be opened by someone aged '
                  '18 or over.',
                )
              : tr(
                  'The date you entered makes you {age}. An account on this '
                  'app can only be opened by someone aged 18 or over.\n\n'
                  'If you are under 18, a parent or guardian can open an '
                  'account on their own number and consult a doctor for you '
                  '— a doctor is required to have an adult present for a '
                  'consultation with a minor.\n\n'
                  'If you entered the wrong date, close this and correct it.',
                  {'age': age},
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(tr('Change date')),
          ),
        ],
      ),
    );
  }

  /// Opens the document the patient is being asked to agree to.
  ///
  /// These used to be dead links. Consent that cannot be read is not informed
  /// consent, which is the whole point of the checkbox above them.
  void _openLegal(ConsentDocument document) {
    Navigator.of(context).pushNamed(switch (document) {
      ConsentDocument.privacyPolicy => AppRoutes.privacyPolicy,
      ConsentDocument.termsAndConditions => AppRoutes.termsAndConditions,
    });
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final busy = _controller.isSaving;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppTopBar(title: 'Complete Profile'),
                Padding(
                  padding: EdgeInsets.only(
                    top: sizing.spacingMd,
                    left: sizing.screenPaddingH,
                    right: sizing.screenPaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr("Let's complete your profile"),
                        style: sizing.text.screenTitleCompact,
                      ),
                      SizedBox(height: sizing.spacingXxs + 2),
                      Text(
                        tr(
                          'This information is required to provide you with '
                          'accurate medical consultations',
                        ),
                        style: sizing.text.helperText,
                      ),
                      SizedBox(height: sizing.spacingXl),
                      AppTextField(
                        label: 'Full Name',
                        hint: 'e.g. Rahul Sharma',
                        controller: _nameTextController,
                        enabled: !busy,
                        errorText: _controller.nameError,
                        keyboardType: TextInputType.name,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        onChanged: _controller.changeFullName,
                      ),
                      SizedBox(height: sizing.spacingXl),
                      _DateOfBirthField(
                        value: _controller.dateOfBirth,
                        errorText: _controller.dateOfBirthError,
                        enabled: !busy,
                        onTap: _pickDateOfBirth,
                      ),
                      SizedBox(height: sizing.spacingXl),
                      AppDropdownField<Gender>(
                        label: 'Gender',
                        hint: 'Select Gender',
                        value: _controller.gender,
                        items: Gender.values,
                        labelOf: (gender) => gender.label,
                        enabled: !busy,
                        errorText: _controller.genderError,
                        onChanged: _controller.changeGender,
                      ),
                      SizedBox(height: sizing.spacingXl),
                      ConsentSection(
                        dataProcessingConsent:
                            _controller.dataProcessingConsent,
                        termsAccepted: _controller.termsAccepted,
                        dataProcessingConsentError:
                            _controller.dataProcessingConsentError,
                        termsAcceptedError: _controller.termsAcceptedError,
                        enabled: !busy,
                        onDataProcessingConsentChanged:
                            _controller.changeDataProcessingConsent,
                        onTermsAcceptedChanged: _controller.changeTermsAccepted,
                        onDocumentTap: _openLegal,
                      ),
                      SizedBox(height: sizing.spacingSm),
                      AppButton.primary(
                        label: 'Continue',
                        isLoading: busy,
                        onPressed: _controller.canSubmit ? _submit : null,
                      ),
                      SizedBox(height: sizing.spacingSm),
                      const ComplianceFooter(),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(height: sizing.screenPaddingV),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A read-only field that opens the date wheel.
///
/// Mirrors `_PickerField` on the edit-profile screen; kept local rather than
/// shared because the two screens are free to diverge and this one carries its
/// own helper text about the 18+ rule.
class _DateOfBirthField extends StatelessWidget {
  const _DateOfBirthField({
    required this.value,
    required this.onTap,
    this.errorText,
    this.enabled = true,
  });

  final DateTime? value;
  final VoidCallback onTap;
  final String? errorText;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final selected = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Date of Birth'), style: sizing.text.fieldLabel),
        SizedBox(height: sizing.spacingSm),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(sizing.radiusInput),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: sizing.w(16),
              vertical: sizing.h(16),
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(sizing.radiusInput),
              border: Border.all(
                color: errorText == null ? AppColors.border : AppColors.danger,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected == null
                        ? tr('Select your date of birth')
                        : AppDateFormat.monthDayYear(selected),
                    style: selected == null
                        ? sizing.text.fieldPlaceholder
                        : sizing.text.fieldValue,
                  ),
                ),
                Icon(
                  Icons.calendar_today_rounded,
                  size: sizing.iconSm,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (errorText case final error?) ...[
          SizedBox(height: sizing.spacingSm),
          Text(tr(error), style: sizing.text.error),
        ] else ...[
          SizedBox(height: sizing.spacingSm),
          Text(
            tr('You must be 18 or older to open an account.'),
            style: sizing.text.helperText,
          ),
        ],
      ],
    );
  }
}
