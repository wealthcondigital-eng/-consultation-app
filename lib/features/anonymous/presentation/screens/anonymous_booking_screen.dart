import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_note_field.dart';
import '../../../../core/widgets/app_segmented_control.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../consultation/domain/entities/consult_option.dart';
import '../../../doctors/presentation/screens/doctor_list_screen.dart';
import '../../domain/entities/anonymous_session.dart';
import '../controllers/anonymous_booking_controller.dart';
import '../widgets/code_name_field.dart';
import '../widgets/consult_language_field.dart';
import '../widgets/privacy_notice.dart';

/// Books a consultation under an alias, with the patient's real identity never
/// leaving the app.
class AnonymousBookingScreen extends StatefulWidget {
  const AnonymousBookingScreen({super.key});

  @override
  State<AnonymousBookingScreen> createState() => _AnonymousBookingScreenState();
}

class _AnonymousBookingScreenState extends State<AnonymousBookingScreen> {
  late final AnonymousBookingController _controller =
      sl<AnonymousBookingController>();

  final TextEditingController _codeNameController = TextEditingController();
  final TextEditingController _concernController = TextEditingController();

  @override
  void dispose() {
    _codeNameController.dispose();
    _concernController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _book() {
    final session = _controller.submit();

    if (session == null) {
      // Only a message the field cannot carry. An alias that will not do is
      // already explained in red under the box it was typed into, and a
      // snackbar saying the same thing is the same sentence twice.
      final message = _controller.errorMessage;
      if (message != null) AppSnackBar.error(context, message);
      return;
    }

    _openMatching(session);
  }

  /// Files the consultation and waits for a doctor to answer.
  ///
  /// Straight into matching, which is the flow every other instant consultation
  /// takes — the alias rides along on the request and is the only name the
  /// doctor is sent.
  ///
  /// It used to go to matching in *discovery* mode, which files nothing, then
  /// to a doctor listing, then to a chat thread against a stub. So an
  /// "anonymous consultation" ended in a conversation with nobody: no
  /// consultation record existed, no doctor was ever rung, and the alias never
  /// left the device.
  void _openMatching(AnonymousSession session) {
    // A booking is a different journey from a call: there is nobody to ring, so
    // the patient picks a doctor and a slot. The alias and the concern travel
    // with them the whole way — it is the same consultation, filed for later.
    if (session.isScheduled) {
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.doctorList,
        arguments: DoctorListArgs(
          mode: session.mode,
          anonymousSession: session,
        ),
      );
      return;
    }

    // Through the listing rather than straight to matching, and the reason is
    // money: a consultation has to be paid for before a doctor's phone rings,
    // and it cannot be priced until there *is* a doctor — they set their own
    // fee and price video and audio separately. "Ring anybody" has no price.
    //
    // So the patient picks from the doctors who are free right now, pays, and
    // the listing rings them. One extra tap, and it closes the last path that
    // filed a consultation nobody had paid for.
    Navigator.of(context).pushReplacementNamed(
      AppRoutes.doctorList,
      arguments: DoctorListArgs(
        mode: session.mode,
        instantOnly: true,
        anonymousSession: session,
      ),
    );
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
        scrollable: false,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AppTopBar(
                  title: 'Anonymous Booking',
                  variant: AppTopBarVariant.outlined,
                  trailing: PrivacyBadge(),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      sizing.screenPaddingH,
                      sizing.spacingXs,
                      sizing.screenPaddingH,
                      sizing.spacingXl,
                    ),
                    children: [
                      const PrivacyNotice(
                        message: 'Your real identity will not be shared',
                      ),
                      SizedBox(height: sizing.spacingLg),
                      Text(tr('When'), style: sizing.text.fieldLabel),
                      SizedBox(height: sizing.spacingXs),
                      // Anonymity is a property of the consultation, not of how
                      // soon it happens. A patient who wants to speak to
                      // somebody under an alias on Thursday is asking for the
                      // same thing as one who wants to now, and until this was
                      // here the only way to get it was to give up the alias.
                      AppSegmentedControl<ConsultOptionKind>(
                        options: ConsultOptionKind.values,
                        selected: _controller.kind,
                        labelOf: (kind) => switch (kind) {
                          ConsultOptionKind.instant => 'Now',
                          ConsultOptionKind.scheduled => 'Book a slot',
                        },
                        iconOf: (kind) => switch (kind) {
                          ConsultOptionKind.instant => Icons.bolt_rounded,
                          ConsultOptionKind.scheduled =>
                            Icons.event_available_rounded,
                        },
                        onSelected: _controller.changeKind,
                      ),
                      SizedBox(height: sizing.spacingSm),
                      // Said rather than offered as a choice. A video call
                      // hands the doctor the patient's face, which undoes the
                      // alias and everything else on this screen — so it is not
                      // one of two equal options one mis-tap away.
                      _VoiceOnlyNote(),
                      SizedBox(height: sizing.spacingLg),
                      CodeNameField(
                        controller: _codeNameController,
                        enabled: true,
                        errorText: _controller.codeNameError,
                        onChanged: _controller.changeCodeName,
                      ),
                      SizedBox(height: sizing.spacingLg),
                      ConsultLanguageField(
                        value: _controller.language,
                        onChanged: _controller.changeLanguage,
                      ),
                      SizedBox(height: sizing.spacingLg),
                      AppNoteField(
                        label: 'Describe your concern',
                        hint:
                            'Would like to discuss stress and anxiety '
                            'management...',
                        controller: _concernController,
                        enabled: true,
                        // No limit or counter: a patient describing something
                        // private should not be made to cut it short.
                        errorText: _controller.concernError,
                        onChanged: _controller.changeConcern,
                      ),
                      SizedBox(height: sizing.spacingXs),
                      // Worth saying, because it changes what a patient writes.
                      // This is the only thing the doctor is told about them,
                      // and they read it while deciding whether to answer.
                      Text(
                        tr(
                          'The doctor sees this before they answer. It is the '
                          'only thing they are told about you.',
                        ),
                        style: sizing.text.caption,
                      ),
                      SizedBox(height: sizing.spacingXl),
                      AppButton.emphasis(
                        label: _controller.kind == ConsultOptionKind.scheduled
                            ? 'Book Anonymously'
                            : 'Find a Doctor Anonymously',

                        // Always tappable: an alias that will not do is
                        // explained under the field rather than by a dead
                        // button.
                        onPressed: _book,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Says that an anonymous consultation is a voice call, and why.
///
/// A note rather than a disabled control. A greyed-out Video segment invites
/// the question "how do I turn that on"; a sentence answers it once and takes
/// the choice off the screen.
class _VoiceOnlyNote extends StatelessWidget {
  const _VoiceOnlyNote();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.mic_rounded,
          size: sizing.iconXs,
          color: AppColors.textSecondary,
        ),
        SizedBox(width: sizing.spacingXs),
        Expanded(
          child: Text(
            tr(
              'Anonymous consultations are voice calls, so the doctor never '
              'sees your face.',
            ),
            style: sizing.text.caption,
          ),
        ),
      ],
    );
  }
}
