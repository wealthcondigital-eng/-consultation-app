import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../../../app/router/app_routes.dart';
import '../../domain/entities/consultation_mode.dart';
import '../../domain/entities/consult_option.dart';
import '../controllers/consult_options_controller.dart';
import '../widgets/consult_option_card.dart';
import '../../../doctors/presentation/screens/doctor_list_screen.dart';
import 'doctor_matching_screen.dart';

/// Where a patient picks how they want to reach a doctor.
class ConsultOptionsScreen extends StatefulWidget {
  const ConsultOptionsScreen({super.key});

  @override
  State<ConsultOptionsScreen> createState() => _ConsultOptionsScreenState();
}

class _ConsultOptionsScreenState extends State<ConsultOptionsScreen> {
  late final ConsultOptionsController _controller =
      sl<ConsultOptionsController>();

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

  Future<void> _start(ConsultOption option) async {
    if (!option.isAvailable) return;

    // The call type is **not** asked for here. It is asked once a doctor has
    // been chosen, because it is a question about that doctor: they may take
    // only one of the two, and they price them separately. Asking first meant
    // committing to video before knowing whether the person you wanted does it.
    //
    // The search runs first either way, and hands over to the listing once it
    // has an answer. Which listing depends on the option: the doctors free
    // right now, or everyone who can be booked.
    await Navigator.of(context).pushNamed(
      AppRoutes.doctorMatching,
      arguments: DoctorMatchingArgs(
        // Only the search needs one, and discovery does not use it.
        mode: ConsultationMode.video,
        listing: DoctorListArgs(
          instantOnly: option.kind == ConsultOptionKind.instant,
        ),
      ),
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
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        scrollable: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppTopBar(
              title: 'Consult Now',
              variant: AppTopBarVariant.outlined,
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller,
                builder: (context, _) {
                  if (_controller.isInitialLoad) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      sizing.screenPaddingH,
                      sizing.spacingLg,
                      sizing.screenPaddingH,
                      sizing.spacingXxl,
                    ),
                    children: [
                      Text(
                        tr(
                          'Select your preferred consultation method. We will '
                          'match you with certified medical experts.',
                        ),
                        style: sizing.text.leadParagraph,
                      ),
                      if (_controller.errorMessage != null) ...[
                        SizedBox(height: sizing.spacingSm),
                        _OptionsError(
                          message: _controller.errorMessage!,
                          onRetry: _controller.load,
                        ),
                      ],
                      for (final option in _controller.options) ...[
                        SizedBox(height: sizing.spacingLg),
                        ConsultOptionCard(
                          option: option,
                          onAction: () => _start(option),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionsError extends StatelessWidget {
  const _OptionsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      children: [
        Expanded(child: Text(tr(message), style: sizing.text.error)),
        TextButton(
          onPressed: onRetry,
          child: Text(tr('Retry'), style: sizing.text.sectionAction),
        ),
      ],
    );
  }
}
