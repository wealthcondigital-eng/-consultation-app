import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../di/service_locator.dart';
import '../logging/auth_logger.dart';
import '../network/api_client.dart';
import '../responsive/app_sizing.dart';
import '../theme/app_colors.dart';

/// A round photo fetched from the API, falling back to initials.
///
/// Exists because a profile photo on this platform is **not** a public URL.
/// `GET /patients/me/photo` and `GET /doctors/me/photo` are behind the same
/// bearer token as the record they belong to — a link that anyone could open
/// either expires and breaks, or does not expire and is a permanent leak of
/// medical-account data.
///
/// The bytes come through [ApiClient.download] rather than `Image.network`.
/// Flutter's image cache keys a network image by URL alone — the headers are
/// not part of the key — and the path is the same `/patients/me/photo` for
/// every account and every photo. So a replaced photo kept showing the old
/// one, a second account on the same phone could be shown the first one's
/// face, and a failed load was swallowed by `errorBuilder` without a word in
/// the log. Here the bytes live in this widget's state, are fetched again
/// whenever [path] changes, and a failure is logged.
///
/// [path] is what the API answered with — `/patients/me/photo`, not a full
/// URL. A query string (`?v=…`) is how a caller says "same path, new photo";
/// the server ignores it.
///
/// Null [path] is the normal case, not an error: most people never set a photo.
/// It renders [initials], and so does a load that fails — a blank circle where
/// a face belongs reads as a bug, and initials never do.
class RemoteAvatar extends StatefulWidget {
  const RemoteAvatar({
    super.key,
    required this.path,
    required this.initials,
    required this.size,
    this.background,
    this.foreground,
    this.semanticLabel,
  });

  /// The API path the photo is served from, or null when there is none.
  final String? path;

  /// One or two letters. What is shown until — or instead of — a photo.
  final String initials;

  final double size;

  /// Defaults to [AppColors.avatarSurface].
  final Color? background;

  /// Defaults to [AppColors.textSecondary].
  final Color? foreground;

  /// Announced by a screen reader, e.g. `Amit Verma profile photo`.
  final String? semanticLabel;

  @override
  State<RemoteAvatar> createState() => _RemoteAvatarState();
}

class _RemoteAvatarState extends State<RemoteAvatar> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RemoteAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  Future<void> _load() async {
    final path = widget.path?.trim();

    // Dropped straight away, so a removed photo does not linger and a new one
    // never flashes the old face first.
    if (_bytes != null) setState(() => _bytes = null);

    if (path == null || path.isEmpty || !sl.isRegistered<ApiClient>()) return;

    try {
      final file = await sl<ApiClient>().download(path);
      // The path may have moved on while this was in flight.
      if (!mounted || widget.path?.trim() != path) return;
      setState(() => _bytes = file.bytes);
    } catch (error) {
      AuthLogger.event('API · avatar load failed', {
        'path': path,
        'error': error,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = _Initials(
      initials: widget.initials,
      size: widget.size,
      color: widget.foreground ?? AppColors.textSecondary,
    );

    return Semantics(
      image: true,
      label: widget.semanticLabel,
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: widget.background ?? AppColors.avatarSurface,
          shape: BoxShape.circle,
        ),
        child: switch (_bytes) {
          final bytes? => Image.memory(
            bytes,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            // Bytes that arrived but do not decode — a format this phone
            // cannot read — still end on initials, and say so in the log.
            errorBuilder: (context, error, _) {
              AuthLogger.event('API · avatar decode failed', {
                'path': widget.path,
                'error': error,
              });
              return fallback;
            },
          ),
          null => fallback,
        },
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.initials,
    required this.size,
    required this.color,
  });

  final String initials;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    // `?` is what callers pass for an anonymous patient or a missing name. A
    // question mark in a circle reads as an error, so it becomes a person.
    if (initials.trim().isEmpty || initials == '?') {
      return Icon(Icons.person_rounded, size: size * 0.55, color: color);
    }

    return Text(
      initials,
      style: sizing.text.headline.copyWith(
        // Proportional to the circle rather than a fixed step, so the same
        // widget reads correctly at 32 and at 100.
        fontSize: size * 0.34,
        color: color,
      ),
    );
  }
}

/// `Amit Verma` → `AV`, and `Dr. Amit Verma` → `AV` too.
///
/// The title is dropped on purpose: every doctor has one, so a circle full of
/// `D`s tells you nothing. Shared rather than reimplemented per screen — the
/// doctor's profile header, the patient roster and the call screen all need the
/// same two letters for the same person.
String initialsOf(String name, {String fallback = '?'}) {
  final words = name
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .where((word) => !_titles.contains(word.toLowerCase()))
      .toList();

  if (words.isEmpty) return fallback;

  return words.take(2).map((word) => word[0].toUpperCase()).join();
}

const Set<String> _titles = {'dr', 'dr.', 'prof', 'prof.', 'mr', 'mrs', 'ms'};
