import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/medical_report.dart';
import '../../domain/usecases/manage_medical_reports.dart';

/// Presentation state for the reports on a patient's medical record.
class MedicalReportsController extends ChangeNotifier {
  MedicalReportsController(this._reports);

  final ManageMedicalReports _reports;

  List<MedicalReport> _items = const [];
  List<MedicalReport> get items => _items;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasLoaded = false;
  bool get isInitialLoad => _isLoading && !_hasLoaded;

  /// True while a file is on its way up. The add button shows a spinner rather
  /// than being merely disabled — an upload over a phone connection takes long
  /// enough that a dead button reads as a broken one.
  bool _isUploading = false;
  bool get isUploading => _isUploading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isEmpty => _hasLoaded && _items.isEmpty;

  Future<void> load() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      _items = await _reports.load();
      _hasLoaded = true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Uploads [filePath] under [title]. Returns false with an explanation on
  /// [errorMessage] when it could not be sent.
  ///
  /// The size is checked **here** rather than only on the server: a 15 MB
  /// photograph refused after the upload is a minute of a phone connection
  /// spent to be told no.
  Future<bool> add({
    required String filePath,
    String title = '',
    MedicalRecordKind kind = MedicalRecordKind.report,
  }) async {
    if (_isUploading) return false;

    final bytes = await _sizeOf(filePath);
    if (bytes != null && bytes > ManageMedicalReports.maxBytes) {
      _errorMessage =
          'That file is larger than 10 MB. Try photographing the page again, '
          'or send a PDF.';
      notifyListeners();
      return false;
    }

    _isUploading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final report = await _reports.add(
        filePath: filePath,
        title: title,
        kind: kind,
      );
      // Prepended rather than reloaded: the list is already right, and a second
      // round trip would blank the screen for a moment after a success.
      _items = [report, ..._items];
      _hasLoaded = true;
      return true;
    } on Failure catch (failure) {
      _errorMessage = failure.message;
      return false;
    } catch (_) {
      _errorMessage = const Failure.unexpected().message;
      return false;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<bool> remove(MedicalReport report) async {
    // Taken off the list first, so the row disappears on the tap. Put back if
    // the server refuses — the alternative is a row that sits there looking
    // deleted-but-not for as long as the request takes.
    final previous = _items;
    _items = _items.where((item) => item.id != report.id).toList();
    notifyListeners();

    try {
      await _reports.remove(report);
      return true;
    } on Failure catch (failure) {
      _items = previous;
      _errorMessage = failure.message;
      notifyListeners();
      return false;
    } catch (_) {
      _items = previous;
      _errorMessage = const Failure.unexpected().message;
      notifyListeners();
      return false;
    }
  }

  void acknowledgeError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Null when the file cannot be measured — on the web, or a path the picker
  /// handed over that no longer exists. The server checks the size too, so an
  /// unmeasurable file is sent rather than refused on a guess.
  Future<int?> _sizeOf(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return null;
    }
  }
}
