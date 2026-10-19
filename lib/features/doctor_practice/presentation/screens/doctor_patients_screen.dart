import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/app_status_view.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/doctor_patient.dart';
import '../controllers/doctor_patients_controller.dart';

/// The doctor's patient roster as a standalone route.
///
/// The doctor shell hosts [DoctorPatientsView] directly instead, so the nav bar
/// stays put when Patients is selected as a tab.
class DoctorPatientsScreen extends StatelessWidget {
  const DoctorPatientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: ResponsivePage(
        backgroundColor: AppColors.canvas,
        scrollable: false,
        child: DoctorPatientsView(),
      ),
    );
  }
}

/// Who this doctor has consulted, most recent first.
///
/// **Anonymous consultations are not here**, and the empty state says so. They
/// stay on the consultation list under the alias the patient chose: grouping
/// them by the account behind it would tell the doctor that two aliases are one
/// person, which is the one thing an anonymous consultation promises not to say.
///
/// Carries no page shell of its own so it can sit inside one that already
/// exists — nesting `ResponsivePage` would double the Scaffold and SafeArea.
class DoctorPatientsView extends StatefulWidget {
  const DoctorPatientsView({super.key});

  @override
  State<DoctorPatientsView> createState() => _DoctorPatientsViewState();
}

class _DoctorPatientsViewState extends State<DoctorPatientsView> {
  late final DoctorPatientsController _controller =
      sl<DoctorPatientsController>();

  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppTopBar(
          title: 'My Patients',
          variant: AppTopBarVariant.outlined,
          centerTitle: true,
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            sizing.screenPaddingH,
            sizing.spacingSm,
            sizing.screenPaddingH,
            sizing.spacingXs,
          ),
          child: AppSearchField(
            controller: _search,
            hint: 'Search by name',
            onChanged: _controller.setSearch,
          ),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => _Body(controller: _controller),
          ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final DoctorPatientsController controller;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    if (controller.isInitialLoad) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.isEmpty) {
      return AppEmptyState(
        icon: Icons.groups_rounded,
        title: controller.search.trim().isEmpty
            ? 'No patients yet'
            : 'Nobody matches that',
        message: controller.search.trim().isEmpty
            ? 'Patients you consult appear here. Anonymous consultations are '
                  'not listed — they stay under the alias the patient chose.'
            : 'Try a different name.',
      );
    }

    final patients = controller.patients;

    return AppRefreshIndicator(
      onRefresh: controller.load,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          sizing.screenPaddingH,
          sizing.spacingXs,
          sizing.screenPaddingH,
          sizing.spacingXxl,
        ),
        itemCount: patients.length + (controller.errorMessage == null ? 0 : 1),
        separatorBuilder: (context, _) => SizedBox(height: sizing.spacingSm),
        itemBuilder: (context, index) {
          if (controller.errorMessage case final message?) {
            if (index == 0) {
              return AppInlineError(message: message, onRetry: controller.load);
            }
            return _PatientCard(patient: patients[index - 1]);
          }

          return _PatientCard(patient: patients[index]);
        },
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  const _PatientCard({required this.patient});

  final DoctorPatient patient;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Row(
        children: [
          RemoteAvatar(
            // A patient's photo is not served to the doctor. The route is
            // `/patients/me/photo` and there is deliberately no shape that
            // could ask for somebody else's — initials are the honest answer.
            path: null,
            initials: initialsOf(patient.name),
            size: sizing.avatarSize,
            semanticLabel: patient.name,
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: sizing.text.cardTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: sizing.spacingXxs / 2),
                Text(
                  patient.consultationsLabel,
                  style: sizing.text.cardSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: sizing.spacingXxs),
                Text(
                  patient.lastSeenLabel,
                  style: sizing.text.metaLabel.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: sizing.spacingXs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                patient.billedLabel,
                style: sizing.text.cardTitle.copyWith(
                  color: AppColors.primaryDeep,
                ),
              ),
              SizedBox(height: sizing.spacingXxs / 2),
              Text(
                tr('billed'),
                style: sizing.text.metaLabel.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
