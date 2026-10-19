import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/widgets/app_checkbox.dart';

/// Names of the documents the consent copy links to.
///
/// Named for the consent screen rather than `LegalDocument`, which is the legal
/// feature's document *content*; these are only the two links shown beside the
/// checkboxes.
///
/// There is deliberately no "Data Processing Agreement" here. A DPA is the
/// contract between us and a processor such as Razorpay or Google — internal
/// paperwork the Data Protection Board may ask to see, and nothing a patient
/// signs. Asking one to agree to it was a mistake.
enum ConsentDocument {
  privacyPolicy('Privacy Policy'),

  /// The title the document actually carries. The screen used to say "Terms of
  /// Service" while the document it opens is "Terms & Conditions".
  termsAndConditions('Terms & Conditions');

  const ConsentDocument(this.title);

  final String title;
}

/// The two consents the DPDP Act requires before a medical profile is stored.
///
/// Stateful because the link tap recognisers hold resources that must be
/// released with the widget.
class ConsentSection extends StatefulWidget {
  const ConsentSection({
    super.key,
    required this.dataProcessingConsent,
    required this.termsAccepted,
    required this.onDataProcessingConsentChanged,
    required this.onTermsAcceptedChanged,
    required this.onDocumentTap,
    this.dataProcessingConsentError,
    this.termsAcceptedError,
    this.enabled = true,
  });

  final bool dataProcessingConsent;
  final bool termsAccepted;
  final ValueChanged<bool> onDataProcessingConsentChanged;
  final ValueChanged<bool> onTermsAcceptedChanged;
  final ValueChanged<ConsentDocument> onDocumentTap;
  final String? dataProcessingConsentError;
  final String? termsAcceptedError;
  final bool enabled;

  @override
  State<ConsentSection> createState() => _ConsentSectionState();
}

class _ConsentSectionState extends State<ConsentSection> {
  final Map<ConsentDocument, TapGestureRecognizer> _recognizers = {};

  @override
  void initState() {
    super.initState();
    for (final document in ConsentDocument.values) {
      _recognizers[document] = TapGestureRecognizer()
        ..onTap = () => widget.onDocumentTap(document);
    }
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TextSpan _link(ConsentDocument document, TextStyle style) {
    return TextSpan(
      text: tr(document.title),
      style: style,
      recognizer: _recognizers[document],
    );
  }

  /// A sentence with a document link inside it, from a template holding
  /// `{link}` where the link goes — so a translation can put the link
  /// wherever its word order needs it.
  List<InlineSpan> _sentence(
    String template,
    ConsentDocument document,
    TextStyle style,
  ) {
    final parts = template.split('{link}');
    final before = parts.first;
    final after = parts.skip(1).join();

    return [
      if (before.isNotEmpty) TextSpan(text: before),
      _link(document, style),
      if (after.isNotEmpty) TextSpan(text: after),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final body = sizing.text.legalBody;
    final link = sizing.text.legalLink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCheckbox(
          value: widget.dataProcessingConsent,
          onChanged: widget.onDataProcessingConsentChanged,
          enabled: widget.enabled,
          errorText: widget.dataProcessingConsentError,
          semanticLabel:
              'I consent to the collection and processing of my '
              'personal data for healthcare consultations.',
          label: Text.rich(
            TextSpan(
              style: body,
              children: _sentence(
                tr(
                  'I consent to the collection and processing of my '
                  'personal data for healthcare consultations as described '
                  'in the {link}.',
                ),
                ConsentDocument.privacyPolicy,
                link,
              ),
            ),
          ),
        ),
        SizedBox(height: sizing.spacingXs + 2),
        AppCheckbox(
          value: widget.termsAccepted,
          onChanged: widget.onTermsAcceptedChanged,
          enabled: widget.enabled,
          errorText: widget.termsAcceptedError,
          semanticLabel: 'I agree to the Terms & Conditions.',
          label: Text.rich(
            TextSpan(
              style: body,
              children: _sentence(
                tr('I agree to the {link}.'),
                ConsentDocument.termsAndConditions,
                link,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
