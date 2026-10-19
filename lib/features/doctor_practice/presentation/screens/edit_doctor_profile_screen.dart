import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/india_locations.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_note_field.dart';
import '../../../../core/widgets/app_select_field.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/doctor_practice_profile.dart';
import '../controllers/doctor_profile_edit_controller.dart';
import '../widgets/language_picker.dart';
import '../widgets/reviewed_fields_card.dart';
import '../../../../core/widgets/app_snackbar.dart';

/// The doctor editing their own record.
///
/// Seven fields, and the ones that are missing are the point: the registration
/// number, the degree and the specialty were read off a certificate a reviewer
/// accepted, so they are shown here read-only with a note saying how to change
/// them. Letting an approved doctor rewrite them would make the approval
/// meaningless — the platform approved a named person holding a named
/// qualification, not a row that can later say something else.
///
/// Pops back the saved profile, so the screen behind folds it in rather than
/// re-reading a page the app just wrote.
class EditDoctorProfileScreen extends StatefulWidget {
  const EditDoctorProfileScreen({super.key});

  @override
  State<EditDoctorProfileScreen> createState() =>
      _EditDoctorProfileScreenState();
}

class _EditDoctorProfileScreenState extends State<EditDoctorProfileScreen> {
  late final DoctorProfileEditController _controller =
      sl<DoctorProfileEditController>();

  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _years = TextEditingController();
  final TextEditingController _bio = TextEditingController();

  /// The fields are seeded once, when the profile arrives. Re-seeding them on
  /// every rebuild would move the caret to the end while somebody was typing.
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(_onChanged)
      ..load();
  }

  @override
  void dispose() {
    for (final field in [_name, _email, _years, _bio]) {
      field.dispose();
    }
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;

    if (!_seeded && _controller.profile != null) {
      _seeded = true;
      final edits = _controller.edits;
      _name.text = edits.fullName;
      _email.text = edits.email;
      _years.text = edits.yearsOfExperience?.toString() ?? '';
      _bio.text = edits.bio;
    }

    final message = _controller.errorMessage;
    if (message == null) return;

    _controller.acknowledgeError();
    AppSnackBar.error(context, message);
  }

  /// The list as options, plus whatever is already on file when it is not in
  /// it — a place typed in before the list existed. Shown rather than blanked,
  /// so opening the screen never looks as if it lost the doctor's location.
  Map<String, String> _withCurrent(Iterable<String> list, String current) {
    return {
      if (current.isNotEmpty && !list.contains(current)) current: current,
      for (final item in list) item: item,
    };
  }

  Future<void> _save() async {
    final saved = await _controller.save();
    if (saved == null || !mounted) return;

    Navigator.of(context).pop(saved);
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
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        scrollable: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppTopBar(
                  title: 'Edit Profile',
                  variant: AppTopBarVariant.outlined,
                ),
                Expanded(child: _body(context)),
                if (_controller.profile != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      sizing.screenPaddingH,
                      sizing.spacingXs,
                      sizing.screenPaddingH,
                      sizing.spacingMd,
                    ),
                    child: AppButton.primary(
                      label: 'Save changes',
                      onPressed: _controller.canSave ? _save : null,
                      isLoading: _controller.isSaving,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final sizing = context.sizing;

    if (_controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    final profile = _controller.profile;
    if (profile == null) {
      return AppErrorView(
        message: _controller.errorMessage ?? 'Your profile is not available.',
        onRetry: _controller.load,
      );
    }

    final edits = _controller.edits;
    final showErrors = _controller.showErrors;

    return ListView(
      padding: EdgeInsets.fromLTRB(
        sizing.screenPaddingH,
        sizing.spacingSm,
        sizing.screenPaddingH,
        sizing.spacingXl,
      ),
      children: [
        AppTextField(
          label: 'Full name',
          hint: 'Amit Verma',
          controller: _name,
          textCapitalization: TextCapitalization.words,
          errorText: showErrors ? edits.nameError : null,
          onChanged: _controller.setFullName,
        ),
        SizedBox(height: sizing.spacingMd),
        AppTextField(
          label: 'Email',
          hint: 'you@example.com',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          helperText: tr('Optional. Used for payout receipts and updates.'),
          errorText: showErrors ? edits.emailError : null,
          onChanged: _controller.setEmail,
        ),
        SizedBox(height: sizing.spacingMd),
        // Picked from the same India list as sign-up, state first because the
        // cities depend on it. Typed free text used to let "mumbai", "Bombay"
        // and "Mumbai " all mean one place to the patients searching for it.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppSelectField<String>(
                label: 'State',
                hint: 'State',
                value: edits.state.isEmpty ? null : edits.state,
                options: _withCurrent(indiaCitiesByState.keys, edits.state),
                onChanged: (state) {
                  if (state == null || state == edits.state) return;
                  _controller.setState_(state);
                  // A city from the old state would be wrong, so it goes.
                  _controller.setCity('');
                },
              ),
            ),
            SizedBox(width: sizing.spacingSm),
            Expanded(
              child: AppSelectField<String>(
                label: 'City',
                hint: 'City',
                value: edits.city.isEmpty ? null : edits.city,
                options: _withCurrent(
                  indiaCitiesByState[edits.state] ?? const [],
                  edits.city,
                ),
                // A city cannot be picked before the state it belongs to.
                enabled: edits.state.isNotEmpty,
                onChanged: (city) {
                  if (city != null) _controller.setCity(city);
                },
              ),
            ),
          ],
        ),
        SizedBox(height: sizing.spacingMd),
        AppTextField(
          label: 'Years of experience',
          hint: '15',
          controller: _years,
          keyboardType: TextInputType.number,
          errorText: showErrors ? edits.yearsError : null,
          onChanged: _controller.setYearsOfExperience,
        ),
        SizedBox(height: sizing.spacingMd),
        AppNoteField(
          label: 'About you',
          hint: 'A line or two patients will read before booking.',
          controller: _bio,
          maxLength: DoctorProfileEdits.maxBioLength,
          errorText: showErrors ? edits.bioError : null,
          onChanged: _controller.setBio,
        ),
        SizedBox(height: sizing.spacingLg),
        LanguagePicker(
          selected: edits.languages,
          onToggle: _controller.toggleLanguage,
        ),
        SizedBox(height: sizing.spacingLg),
        ReviewedFieldsCard(profile: profile),
      ],
    );
  }
}
