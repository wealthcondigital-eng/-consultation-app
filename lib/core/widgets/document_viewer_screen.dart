import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfx/pdfx.dart';

import '../di/service_locator.dart';
import '../error/failure.dart';
import '../network/api_client.dart';
import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';
import 'app_status_view.dart';
import 'app_top_bar.dart';
import '../l10n/tr.dart';

/// What the viewer was opened on.
class DocumentViewerArgs {
  const DocumentViewerArgs({
    required this.title,
    required this.path,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  /// The API path the bytes are fetched from, over the session's token.
  final String path;
}

/// Shows a stored document — a scan or a PDF.
///
/// Used by both sides: a doctor checking which certificate a reviewer rejected,
/// and a patient re-reading a lab result they uploaded. In `core` rather than
/// under either feature because it knows nothing about either — it takes a path
/// and a title, and the caller knows what it is showing.
///
/// The bytes come through the app rather than a browser because the file is
/// behind the same bearer token as the record: a link anyone could open either
/// expires and breaks, or does not expire and is a permanent handle on somebody
/// else's identity paperwork. Neither is a trade worth making for a preview.
///
/// Held in memory and never written to disk. A certificate cached in the
/// device's downloads folder outlives the session that was entitled to it, and
/// there is nothing here that a re-fetch does not answer.
class DocumentViewerScreen extends StatefulWidget {
  const DocumentViewerScreen({super.key, required this.args});

  final DocumentViewerArgs args;

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  DownloadedFile? _file;
  PdfControllerPinch? _pdf;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pdf?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final file = await sl<ApiClient>().download(widget.args.path);
      if (!mounted) return;

      setState(() {
        _file = file;
        // Opened from the bytes rather than a path, which is the whole reason
        // nothing is written to disk.
        _pdf = file.isPdf
            ? PdfControllerPinch(document: PdfDocument.openData(file.bytes))
            : null;
      });
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppColors.overlayOnCanvas.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: AppColors.canvas,
        systemNavigationBarIconBrightness: AppColors.navIconBrightness,
      ),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTopBar(
                title: widget.args.title,
                variant: AppTopBarVariant.outlined,
              ),
              // The file's own name and size, under the title rather than in
              // it: what the doctor is checking is which of two scans this is,
              // and `mbbs-degree.pdf` answers that where a category never can.
              if (widget.args.subtitle case final subtitle?)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    context.sizing.screenPaddingH,
                    context.sizing.spacingXs,
                    context.sizing.screenPaddingH,
                    0,
                  ),
                  child: Text(
                    subtitle,
                    style: context.sizing.text.metaLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_errorMessage case final message?) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Could not open it',
        message: message,
        actionLabel: 'Try again',
        onAction: _load,
      );
    }

    final file = _file;
    if (file == null) return const SizedBox.shrink();

    if (_pdf case final controller?) {
      return PdfViewPinch(controller: controller);
    }

    if (file.isImage) {
      // Pinch and pan, because the thing a doctor opens a scan to check is
      // usually a registration number in small print.
      return InteractiveViewer(
        maxScale: 6,
        child: Center(child: Image.memory(file.bytes, fit: BoxFit.contain)),
      );
    }

    // Neither an image nor a PDF. The API only accepts those two families, so
    // this is a document filed before that rule or one whose type was lost —
    // rare, and better said plainly than rendered as a broken box.
    return AppEmptyState(
      icon: Icons.description_outlined,
      title: 'Cannot preview this file',
      message: tr(
        'It was filed as {type}, which the app cannot display. '
        'The reviewer can still open it.',
        {'type': file.mimeType},
      ),
    );
  }
}
