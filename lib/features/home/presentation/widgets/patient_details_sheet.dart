import 'package:flutter/material.dart';

import '../../../../core/di/service_locator.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/format/app_date_format.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/remote_avatar.dart';
import '../../../consultation/presentation/widgets/consultation_mode_sheet.dart';
import '../../../doctor_practice/domain/entities/doctor_earnings.dart';
import '../../../doctor_practice/domain/entities/doctor_patient_detail.dart';
import '../../../doctor_practice/domain/usecases/manage_doctor_practice.dart';
import '../../domain/entities/doctor_appointment.dart';
import '../../../../core/l10n/tr.dart';

/// Who the doctor is about to consult, before they consult them.
///
/// Opened from the patient's name on a schedule card. The appointment itself
/// carries the urgent half — the concern, the mode, the time — and it is on
/// screen the moment the sheet opens, because the doctor tapping this is often
/// mid-call-decision and must not wait on a request to read the reason.
/// Everything else loads underneath it.
///
/// **Anonymous consultations show the card's half and stop there.** There is no
/// id to fetch a history with, and that is the promise rather than a gap: an
/// alias joined to an account is the one thing anonymity here rules out. The
/// sheet says so instead of showing an empty history that reads as a patient
/// with no past.
class PatientDetailsSheet extends StatefulWidget {
  const PatientDetailsSheet({super.key, required this.appointment});

  final DoctorAppointment appointment;

  /// A sheet on a phone, a dialog on a tablet.
  ///
  /// The same content either way. A bottom sheet on a wide screen is a strip of
  /// text across the foot of an otherwise empty page, and a dialog on a phone
  /// is a box with no room for the history under it.
  static Future<void> show(
    BuildContext context, {
    required DoctorAppointment appointment,
  }) {
    final sizing = context.sizing;
    final sheet = PatientDetailsSheet(appointment: appointment);

    if (sizing.isCompact) {
      return showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        isScrollControlled: true,
        // Never the full height: a sheet that reaches the status bar reads as a
        // screen, and this one is closed by dragging it down.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(sizing.radiusLg),
          ),
        ),
        builder: (_) => sheet,
      );
    }

    return showDialog<void>(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.45),
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        insetPadding: EdgeInsets.all(sizing.spacingLg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(sizing.radiusLg),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: sizing.w(520),
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: sheet,
        ),
      ),
    );
  }

  @override
  State<PatientDetailsSheet> createState() => _PatientDetailsSheetState();
}

class _PatientDetailsSheetState extends State<PatientDetailsSheet> {
  DoctorPatientDetail? _detail;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final patientId = widget.appointment.patientId;
    if (patientId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final detail = await sl<GetPatientDetail>()(patientId);
      if (mounted) setState(() => _detail = detail);
    } on Failure catch (failure) {
      if (mounted) setState(() => _errorMessage = failure.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = const Failure.unexpected().message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final appointment = widget.appointment;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          sizing.screenPaddingH,
          sizing.spacingXs,
          sizing.screenPaddingH,
          sizing.spacingLg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(appointment: appointment),
            SizedBox(height: sizing.spacingMd),
            _Facts(appointment: appointment),
            if (appointment.concern case final concern?) ...[
              SizedBox(height: sizing.spacingMd),
              _Block(
                title: 'Why they are consulting',
                child: Text(concern, style: sizing.text.bodySmall),
              ),
            ],
            SizedBox(height: sizing.spacingMd),
            if (appointment.isAnonymous)
              const _AnonymousNote()
            else if (_detail case final detail?)
              _History(detail: detail)
            else if (_errorMessage case final message?)
              _Message(
                icon: Icons.error_outline_rounded,
                text: message,
                onRetry: _load,
              )
            else if (_isLoading)
              const _Loading()
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.appointment});

  final DoctorAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      children: [
        // Anonymous consultations carry no id, so there is nothing to fetch and
        // the avatar falls back to its glyph — which is the right picture of a
        // patient whose face the doctor is not entitled to.
        RemoteAvatar(
          path: appointment.patientId == null
              ? null
              : '/doctors/me/patients/${appointment.patientId}/photo',
          initials: _initials(appointment.patientName),
          size: sizing.avatarSize * 1.2,
          background: appointment.isAnonymous
              ? AppColors.anonymousAccent.surface
              : AppColors.avatarSurface,
          semanticLabel: tr('{name} profile photo', {
            'name': appointment.patientName,
          }),
        ),
        SizedBox(width: sizing.spacingSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                appointment.patientName,
                style: sizing.text.sectionTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: sizing.spacingXxs),
              Text(
                appointment.isAnonymous
                    ? tr('Anonymous consultation')
                    : appointment.isScheduled
                    ? tr('Booked appointment')
                    : tr('Instant consultation'),
                style: sizing.text.cardSubtitle,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';

    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }
}

/// When, and how. The two things the doctor is about to act on.
class _Facts extends StatelessWidget {
  const _Facts({required this.appointment});

  final DoctorAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Wrap(
      spacing: sizing.spacingXs,
      runSpacing: sizing.spacingXs,
      children: [
        _Chip(
          icon: Icons.event_rounded,
          label:
              '${AppDateFormat.dayLabel(appointment.startsAt)} · '
              '${appointment.timeLabel}',
        ),
        _Chip(
          icon: iconForConsultationMode(appointment.mode),
          label: appointment.modeLabel,
        ),
        _Chip(icon: Icons.flag_outlined, label: appointment.status.label),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: sizing.spacingSm,
        vertical: sizing.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: sizing.iconXs * 0.85, color: AppColors.textTertiary),
          SizedBox(width: sizing.spacingXxs),
          Text(tr(label), style: sizing.text.metaLabel),
        ],
      ),
    );
  }
}

/// What this doctor has seen this patient for.
class _History extends StatelessWidget {
  const _History({required this.detail});

  final DoctorPatientDetail detail;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final patient = detail.patient;

    return _Block(
      title: 'With you',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Consultations',
                  value: '${patient.consultations}',
                ),
              ),
              Expanded(
                child: _Stat(label: 'Billed', value: patient.billedLabel),
              ),
            ],
          ),
          if (detail.hasHistory) ...[
            SizedBox(height: sizing.spacingSm),
            Container(height: sizing.hairline, color: AppColors.dividerFaint),
            SizedBox(height: sizing.spacingXs),
            // Capped. This is context for a decision being made now, not the
            // patient's file — the Patients tab holds the whole of it.
            for (final entry in detail.history.take(4)) _Visit(entry: entry),
          ] else ...[
            SizedBox(height: sizing.spacingXs),
            Text(
              tr('This is your first consultation with them.'),
              style: sizing.text.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Visit extends StatelessWidget {
  const _Visit({required this.entry});

  final EarningsEntry entry;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: sizing.spacingXxs),
      child: Row(
        children: [
          Icon(
            iconForConsultationMode(entry.mode),
            size: sizing.iconXs * 0.85,
            color: AppColors.textTertiary,
          ),
          SizedBox(width: sizing.spacingXs),
          Expanded(
            child: Text(
              tr(entry.whenLabel),
              style: sizing.text.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(tr(entry.detailLabel), style: sizing.text.metaLabel),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr(label), style: sizing.text.metaLabel),
        SizedBox(height: sizing.spacingXxs * 0.5),
        Text(
          value,
          style: sizing.text.cardTitle.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

/// Says why there is nothing more, rather than showing an empty history that
/// reads as a patient who has never consulted anyone.
class _AnonymousNote extends StatelessWidget {
  const _AnonymousNote();

  @override
  Widget build(BuildContext context) {
    return const _Message(
      icon: Icons.lock_outline_rounded,
      text:
          'This patient booked anonymously, so their past consultations are '
          'not linked to this one.',
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: sizing.spacingMd),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.spacingSm),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(sizing.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: sizing.iconSm, color: AppColors.textTertiary),
          SizedBox(width: sizing.spacingXs),
          Expanded(child: Text(tr(text), style: sizing.text.bodySmall)),
          if (onRetry case final retry?) ...[
            SizedBox(width: sizing.spacingXs),
            TextButton(onPressed: retry, child: Text(tr('Retry'))),
          ],
        ],
      ),
    );
  }
}

/// A titled panel. Used for anything under the facts row.
class _Block extends StatelessWidget {
  const _Block({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr(title),
          style: sizing.text.metaLabel.copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: sizing.spacingXs),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(sizing.spacingSm),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(sizing.radiusMd),
          ),
          child: child,
        ),
      ],
    );
  }
}
