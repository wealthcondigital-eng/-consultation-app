import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/format/app_date_format.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_date_wheel_sheet.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/blood_group.dart';
import '../../domain/entities/gender.dart';
import '../../domain/entities/patient_account.dart';
import '../../domain/entities/patient_details.dart';
import '../controllers/edit_profile_controller.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// Edits the personal details on My Profile.
///
/// Pops `true` once something was saved, so the profile screen reloads instead
/// of continuing to show the values the patient just changed.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.account});

  final PatientAccount account;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final EditProfileController _controller = sl<EditProfileController>();

  late final TextEditingController _nameTextController;
  late final TextEditingController _emailTextController;

  @override
  void initState() {
    super.initState();
    _controller.start(widget.account);
    _nameTextController = TextEditingController(text: widget.account.fullName);
    _emailTextController = TextEditingController(text: widget.account.email);
  }

  @override
  void dispose() {
    _nameTextController.dispose();
    _emailTextController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final selected = await AppDateWheelSheet.show(
      context,
      initial: _controller.details.dateOfBirth ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - PatientDetails.maxAgeYears),
      lastDate: now,
      title: 'Date of birth',
    );

    if (selected != null) _controller.changeDateOfBirth(selected);
  }

  Future<void> _save() async {
    final saved = await _controller.save();
    if (!mounted) return;

    if (!saved) {
      final message = _controller.errorMessage;
      if (message != null) {
        AppSnackBar.error(context, message);
      }
      return;
    }

    // The stored record when the server sent it, so My Profile shows exactly
    // what was saved without a second read; otherwise true, and it re-reads.
    Navigator.of(context).pop<Object>(_controller.savedAccount ?? true);
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return ResponsivePage(
      backgroundColor: AppColors.canvas,
      scrollable: false,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final details = _controller.details;
          final busy = _controller.isSaving;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppTopBar(
                title: 'Edit Profile',
                variant: AppTopBarVariant.outlined,
                centerTitle: true,
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    sizing.screenPaddingH,
                    sizing.spacingXl,
                    sizing.screenPaddingH,
                    sizing.spacingXxl,
                  ),
                  children: [
                    AppTextField(
                      label: 'Full Name',
                      hint: 'e.g. Rahul Sharma',
                      controller: _nameTextController,
                      enabled: !busy,
                      errorText: _controller.nameError,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      onChanged: _controller.changeFullName,
                    ),
                    SizedBox(height: sizing.spacingXl),
                    AppTextField(
                      label: 'Email',
                      hint: 'e.g. rahul@example.com',
                      controller: _emailTextController,
                      enabled: !busy,
                      errorText: _controller.emailError,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: _controller.changeEmail,
                    ),
                    SizedBox(height: sizing.spacingXl),
                    _VerifiedPhoneField(number: _controller.phoneNumber),
                    SizedBox(height: sizing.spacingXl),
                    _PickerField(
                      label: 'Date of Birth',
                      value: details.dateOfBirth == null
                          ? null
                          : AppDateFormat.monthDayYear(details.dateOfBirth!),
                      hint: 'Select your date of birth',
                      errorText: _controller.dateOfBirthError,
                      enabled: !busy,
                      onTap: _pickDateOfBirth,
                    ),
                    SizedBox(height: sizing.spacingXl),
                    AppSelectField<Gender>(
                      label: 'Gender',
                      hint: 'Select gender',
                      value: details.gender,
                      enabled: !busy,
                      options: {
                        for (final gender in Gender.values)
                          gender: gender.label,
                      },
                      onChanged: _controller.changeGender,
                    ),
                    SizedBox(height: sizing.spacingXl),
                    AppSelectField<BloodGroup>(
                      label: 'Blood Group',
                      hint: 'Select blood group',
                      value: details.bloodGroup,
                      enabled: !busy,
                      options: {
                        for (final group in BloodGroup.values)
                          group: group.label,
                      },
                      onChanged: _controller.changeBloodGroup,
                    ),
                    SizedBox(height: sizing.spacingXxl),
                    AppButton.primary(
                      label: busy ? tr('Saving...') : tr('Save Changes'),
                      onPressed: _controller.canSave ? _save : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The phone number, shown for context but not editable here: it is the
/// verified identity the whole account hangs off.
class _VerifiedPhoneField extends StatelessWidget {
  const _VerifiedPhoneField({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Phone Number'), style: sizing.text.fieldLabel),
        SizedBox(height: sizing.spacingSm),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: sizing.w(16),
            vertical: sizing.h(16),
          ),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(sizing.radiusInput),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(child: Text(number, style: sizing.text.fieldValue)),
              Icon(
                Icons.verified_rounded,
                size: sizing.iconSm,
                color: AppColors.success,
              ),
            ],
          ),
        ),
        SizedBox(height: sizing.spacingSm),
        Text(
          tr('Verified by OTP. Changing it needs a new verification.'),
          style: sizing.text.helperText,
        ),
      ],
    );
  }
}

/// A read-only field that opens a picker instead of a keyboard.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onTap,
    this.errorText,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final String hint;
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
        Text(tr(label), style: sizing.text.fieldLabel),
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
                    selected ?? tr(hint),
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
        ],
      ],
    );
  }
}
