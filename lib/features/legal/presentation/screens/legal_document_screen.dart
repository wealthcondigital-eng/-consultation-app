import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/legal_document.dart';
import '../../../../core/l10n/tr.dart';

/// Renders any [LegalDocument].
///
/// One screen for the privacy policy, the terms and the data-protection notice,
/// because they are the same shape: a title, a date, an opening line and a run
/// of headed sections. Three screens would be three places to fix the same
/// typography.
class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.document});

  final LegalDocument document;

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
            AppTopBar(
              title: document.title,
              variant: AppTopBarVariant.outlined,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  sizing.screenPaddingH,
                  sizing.spacingMd,
                  sizing.screenPaddingH,
                  sizing.spacingXxl,
                ),
                children: [
                  Text(
                    tr('Last updated {date}', {'date': document.updatedOn}),
                    style: sizing.text.metaLabel,
                  ),
                  SizedBox(height: sizing.spacingSm),
                  Text(
                    document.intro,
                    style: sizing.text.bodySmall.copyWith(height: 1.55),
                  ),
                  SizedBox(height: sizing.spacingLg),
                  for (final section in document.sections) ...[
                    if (section != document.sections.first)
                      SizedBox(height: sizing.spacingLg),
                    Text(
                      section.heading,
                      style: sizing.text.cardTitle.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: sizing.spacingXs),
                    for (final paragraph in section.body) ...[
                      if (paragraph != section.body.first)
                        SizedBox(height: sizing.spacingXs),
                      _Paragraph(text: paragraph),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A bulleted line.
///
/// A dot rather than a plain paragraph: every section here is a list of
/// distinct commitments, and run together as prose they read as one long
/// sentence that nobody finishes.
class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: sizing.spacingXs * 0.75),
          child: Container(
            width: sizing.r(5),
            height: sizing.r(5),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        SizedBox(width: sizing.spacingXs),
        Expanded(
          child: Text(
            text,
            style: sizing.text.bodySmall.copyWith(height: 1.55),
          ),
        ),
      ],
    );
  }
}
