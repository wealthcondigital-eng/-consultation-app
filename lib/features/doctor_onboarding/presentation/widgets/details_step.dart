import 'package:flutter/material.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_dropdown_field.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../doctor_practice/presentation/widgets/language_picker.dart';
import '../../domain/entities/doctor_credentials.dart';
import '../controllers/doctor_setup_controller.dart';
import 'onboarding_banner.dart';
import '../../../../core/l10n/tr.dart';

/// Step two: the professional details, pre-filled from the certificate where
/// the parse managed it.
class DetailsStep extends StatelessWidget {
  const DetailsStep({
    super.key,
    required this.controller,
    required this.nameController,
    required this.registrationController,
  });

  final DoctorSetupController controller;

  /// Owned by the screen so they survive a step change.
  final TextEditingController nameController;
  final TextEditingController registrationController;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final credentials = controller.credentials;
    final options = controller.options;
    final showErrors = controller.showErrors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.isAutoFilled) ...[
          OnboardingBanner(
            icon: Icons.verified_rounded,
            message:
                'Details auto-filled and validated from your medical '
                'certificate.',
            foreground: AppColors.success,
          ),
          SizedBox(height: sizing.spacingLg),
        ],
        AppTextField(
          label: 'Full Name',
          hint: 'Dr. Sarah Jenkins',
          controller: nameController,
          textCapitalization: TextCapitalization.words,
          errorText: showErrors ? credentials.fullNameError : null,
          trailing: _VerifiedTick(
            isVerified: credentials.isVerified(DoctorCredentialField.fullName),
          ),
          onChanged: (value) => controller.changeCredentials(
            (current) => current.copyWith(fullName: value),
          ),
        ),
        SizedBox(height: sizing.spacingLg),
        AppDropdownField<String>(
          label: 'Medical Degree',
          hint: 'Choose your degree',
          value: credentials.medicalDegree,
          items: options.degrees,
          labelOf: (degree) => degree,
          errorText: showErrors && credentials.medicalDegree == null
              ? 'Choose your medical degree.'
              : null,
          onChanged: (degree) => controller.changeCredentials(
            (current) => current.copyWith(medicalDegree: degree),
          ),
        ),
        SizedBox(height: sizing.spacingLg),
        AppTextField(
          label: 'Registration Number',
          hint: 'REG-9920-A',
          controller: registrationController,
          textCapitalization: TextCapitalization.characters,
          errorText: showErrors ? credentials.registrationNumberError : null,
          trailing: _VerifiedTick(
            isVerified: credentials.isVerified(
              DoctorCredentialField.registrationNumber,
            ),
          ),
          onChanged: (value) => controller.changeCredentials(
            (current) => current.copyWith(registrationNumber: value),
          ),
        ),
        SizedBox(height: sizing.spacingLg),
        // A searchable sheet rather than a dropdown: the list is long, and no
        // list covers every specialty, so a doctor can type their own.
        AppSelectField<String>(
          label: 'Specialty',
          hint: 'Choose your specialty',
          value: credentials.specialty,
          options: {
            for (final specialty in options.specialities) specialty: specialty,
          },
          customValue: _titleCase,
          errorText: showErrors && credentials.specialty == null
              ? 'Choose your specialty.'
              : null,
          onChanged: (specialty) => controller.changeCredentials(
            (current) => current.copyWith(specialty: specialty),
          ),
        ),
        SizedBox(height: sizing.spacingLg),
        LanguagePicker(
          selected: credentials.languages,
          onToggle: (language) => controller.changeCredentials(
            (current) => current.copyWith(
              languages: _toggled(current.languages, language),
            ),
          ),
        ),
        if (showErrors && credentials.languages.isEmpty) ...[
          SizedBox(height: sizing.spacingXs),
          Text(tr('Choose at least one language.'), style: sizing.text.error),
        ],
        SizedBox(height: sizing.spacingLg),
        _StateAndCity(controller: controller),
        SizedBox(height: sizing.spacingLg),
        AppDropdownField<int>(
          label: 'Years of Experience',
          hint: 'Choose your experience',
          value: credentials.yearsOfExperience,
          items: options.experienceYears,
          labelOf: (years) =>
              tr(years == 1 ? '{n} Year' : '{n} Years', {'n': years}),
          errorText: showErrors && credentials.yearsOfExperience == null
              ? 'Choose how long you have practised.'
              : null,
          onChanged: (years) => controller.changeCredentials(
            (current) => current.copyWith(yearsOfExperience: years),
          ),
        ),
      ],
    );
  }
}

/// [languages] with [language] added, or removed if it was there.
List<String> _toggled(List<String> languages, String language) {
  final lower = language.toLowerCase();
  final has = languages.any((entry) => entry.toLowerCase() == lower);

  return has
      ? [
          for (final entry in languages)
            if (entry.toLowerCase() != lower) entry,
        ]
      : [...languages, language];
}

/// `child psychiatry` → `Child Psychiatry`, so a typed specialty reads like
/// the listed ones on a patient's screen. Only first letters change, so an
/// acronym like `ENT` survives.
String _titleCase(String typed) => typed
    .trim()
    .split(RegExp(r'\s+'))
    .map(
      (word) => word.isEmpty ? word : word[0].toUpperCase() + word.substring(1),
    )
    .join(' ');

/// State and city sit side by side, and stack when the screen is too narrow
/// for two dropdowns to stay legible.
class _StateAndCity extends StatelessWidget {
  const _StateAndCity({required this.controller});

  final DoctorSetupController controller;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final credentials = controller.credentials;
    final options = controller.options;
    final showErrors = controller.showErrors;

    // A sheet with search rather than a dropdown: India has 36 states and
    // territories, and a big state has dozens of cities — a floating menu
    // that long cannot be scrolled with any confidence.
    final state = AppSelectField<String>(
      label: 'State',
      hint: 'State',
      value: credentials.state,
      options: {for (final state in options.states) state: state},
      errorText: showErrors && credentials.state == null ? 'Required' : null,
      onChanged: controller.changeState,
    );

    final city = AppSelectField<String>(
      label: 'City',
      hint: 'City',
      value: credentials.city,
      options: {
        for (final city in options.citiesIn(credentials.state)) city: city,
      },
      // A city cannot be picked before the state it belongs to.
      enabled: credentials.state != null,
      errorText: showErrors && credentials.city == null ? 'Required' : null,
      onChanged: (city) => controller.changeCredentials(
        (current) => current.copyWith(city: city),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < sizing.w(320)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              state,
              SizedBox(height: sizing.spacingLg),
              city,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: state),
            SizedBox(width: sizing.spacingSm),
            Expanded(child: city),
          ],
        );
      },
    );
  }
}

/// The tick on a field the register confirmed.
class _VerifiedTick extends StatelessWidget {
  const _VerifiedTick({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    if (!isVerified) return const SizedBox.shrink();

    return Semantics(
      label: tr('Verified'),
      child: Icon(
        Icons.check_circle_rounded,
        size: sizing.iconSm,
        color: AppColors.success,
      ),
    );
  }
}
