import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';

/// Terms/privacy consent line plus the data-use footnote.
///
/// Stateful because the tap recognisers behind the links hold resources that
/// must be released with the widget.
class LegalNotice extends StatefulWidget {
  const LegalNotice({
    super.key,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  State<LegalNotice> createState() => _LegalNoticeState();
}

class _LegalNoticeState extends State<LegalNotice> {
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => widget.onTermsTap();
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => widget.onPrivacyTap();
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final text = sizing.text;

    // One sentence, translated whole, then cut at the two links — so a
    // language that puts the verb last can still order the pieces its own way.
    final sentence = tr(
      'By continuing, you agree to our {terms} and {privacy}.',
    );
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in RegExp(r'\{(terms|privacy)\}').allMatches(sentence)) {
      if (match.start > start) {
        spans.add(TextSpan(text: sentence.substring(start, match.start)));
      }
      final isTerms = match.group(1) == 'terms';
      spans.add(
        TextSpan(
          text: tr(isTerms ? 'Terms of Service' : 'Privacy Policy'),
          style: text.legalLink,
          recognizer: isTerms ? _termsRecognizer : _privacyRecognizer,
        ),
      );
      start = match.end;
    }
    if (start < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(start)));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(TextSpan(style: text.legalBody, children: spans)),
        SizedBox(height: sizing.spacingXxs + 2),
        Text(
          tr(
            'Your phone number is used solely for authentication and account '
            'verification.',
          ),
          style: text.legalFootnote,
        ),
      ],
    );
  }
}
