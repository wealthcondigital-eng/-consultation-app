import 'package:flutter/material.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/l10n/tr.dart';
import '../../../../core/session/auth_session.dart';
import '../../../profile/presentation/widgets/profile_section.dart';
import '../../data/recordings_remote_data_source.dart';
import '../controllers/recordings_controller.dart';

/// "Call recordings · 2 recordings" on the profile — one row, like My
/// Appointments beside it, opening the recordings screen.
///
/// On both profiles: the patient recorded the call, and the doctor in it may
/// play it back too.
class RecordingsEntryRow extends StatefulWidget {
  const RecordingsEntryRow({super.key, this.showDivider = false});

  final bool showDivider;

  @override
  State<RecordingsEntryRow> createState() => _RecordingsEntryRowState();
}

class _RecordingsEntryRowState extends State<RecordingsEntryRow> {
  late final RecordingsController _controller = RecordingsController(
    sl<RecordingsRemoteDataSource>(),
    viewerUserId: sl<AuthSession>().userId,
  )..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final count = _controller.recordings.length;

        return ProfileActionRow(
          icon: Icons.video_library_rounded,
          label: 'Call recordings',
          subtitle: _controller.isLoading && count == 0
              ? tr('Loading…')
              : count == 0
              ? tr('No recordings yet')
              : tr(count == 1 ? '1 recording' : '{n} recordings', {'n': count}),
          showDivider: widget.showDivider,
          onTap: () => Navigator.of(context)
              .pushNamed(AppRoutes.recordings)
              // Back from the list with anything new uploaded meanwhile.
              .then((_) => _controller.load()),
        );
      },
    );
  }
}
