import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../data/recordings_remote_data_source.dart';
import '../../domain/entities/call_recording.dart';

/// The recordings list and one thread's recordings.
class RecordingsController extends ChangeNotifier {
  RecordingsController(this._source, {required this.viewerUserId});

  final RecordingsRemoteDataSource _source;

  /// Who is looking — decides which side of each recording is "the other
  /// person" a thread is named after.
  final String? viewerUserId;

  List<CallRecording> _recordings = const [];
  List<CallRecording> get recordings => _recordings;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  bool _disposed = false;

  /// One thread per counterpart, the most recent first.
  List<RecordingThread> get threads {
    final byCounterpart = <String, List<CallRecording>>{};
    final parties = <String, RecordingParty>{};

    for (final recording in _recordings) {
      final counterpart = recording.counterpartOf(viewerUserId);
      parties.putIfAbsent(counterpart.userId, () => counterpart);
      byCounterpart.putIfAbsent(counterpart.userId, () => []).add(recording);
    }

    return [
      for (final entry in byCounterpart.entries)
        RecordingThread(
          counterpart: parties[entry.key]!,
          recordings: entry.value,
        ),
    ];
  }

  Future<void> load({String? withUserId}) async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      final rows = await _source.fetch(withUserId: withUserId);
      _recordings = [...rows]
        ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    } on Failure catch (failure) {
      _error = failure.message;
    } catch (_) {
      _error = 'Could not load your recordings. Pull down to try again.';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
