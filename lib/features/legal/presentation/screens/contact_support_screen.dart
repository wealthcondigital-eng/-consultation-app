import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_top_bar.dart';
import '../../../../core/widgets/responsive_page.dart';
import '../../domain/entities/legal_document.dart';
import '../../../../core/l10n/tr.dart';

/// How to reach a person.
///
/// Every row here does something rather than displaying a string: an email
/// address a patient has to retype into their mail app is an email address that
/// does not get written. Tapping opens the dialler or the mail composer, and a
/// long press copies, for the device where neither is installed.
class ContactSupportScreen extends StatelessWidget {
  const ContactSupportScreen({super.key});

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
            const AppTopBar(
              title: 'Contact Us',
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
                  const _EmergencyNote(),
                  SizedBox(height: sizing.spacingLg),
                  _Card(
                    children: [
                      _ContactRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email us',
                        value: SupportDetails.email,
                        note: SupportDetails.responseTime,
                        uri: Uri(
                          scheme: 'mailto',
                          path: SupportDetails.email,
                          queryParameters: const {
                            'subject': 'App support request',
                          },
                        ),
                        // Email is the only support channel — no phone.
                        showDivider: false,
                      ),
                    ],
                  ),
                  SizedBox(height: sizing.spacingLg),
                  Text(tr('Data protection'), style: sizing.text.sectionTitle),
                  SizedBox(height: sizing.spacingXs),
                  _Card(
                    children: [
                      _ContactRow(
                        icon: Icons.gavel_rounded,
                        label: SupportDetails.grievanceOfficer,
                        value: SupportDetails.grievanceEmail,
                        // The Act asks for a named route for data complaints,
                        // kept apart from ordinary support so a complaint about
                        // how data was handled does not land in a queue about
                        // login problems.
                        note: 'For complaints about how your data is handled',
                        uri: Uri(
                          scheme: 'mailto',
                          path: SupportDetails.grievanceEmail,
                          queryParameters: const {
                            'subject': 'Data protection grievance',
                          },
                        ),
                        showDivider: false,
                      ),
                    ],
                  ),
                  SizedBox(height: sizing.spacingLg),
                  Text(
                    tr('Registered office'),
                    style: sizing.text.sectionTitle,
                  ),
                  SizedBox(height: sizing.spacingXs),
                  _Card(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(sizing.cardPadding),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: sizing.iconSm,
                              color: AppColors.textTertiary,
                            ),
                            SizedBox(width: sizing.spacingSm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (final line in SupportDetails.address)
                                    Text(
                                      line,
                                      style: sizing.text.bodySmall.copyWith(
                                        height: 1.5,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Above everything else, because it is the one case where the right answer is
/// to close the app.
class _EmergencyNote extends StatelessWidget {
  const _EmergencyNote();

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      padding: EdgeInsets.all(sizing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.dangerSurface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.emergency_outlined,
            size: sizing.iconSm,
            color: AppColors.danger,
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('In an emergency'),
                  style: sizing.text.cardTitle.copyWith(
                    color: AppColors.danger,
                  ),
                ),
                SizedBox(height: sizing.spacingXxs),
                Text(
                  tr(
                    'Call your local emergency number or go to the nearest '
                    'hospital. Support cannot help with a medical emergency.',
                  ),
                  style: sizing.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(sizing.radiusLg),
        border: Border.all(width: sizing.hairline, color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
    required this.uri,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final String note;

  /// `mailto:` or `tel:`. Opened on tap.
  final Uri uri;

  final bool showDivider;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);

    // A device with no mail app, or a tablet with no dialler. Copying is the
    // useful thing to do then — better than a tap that appears to do nothing.
    if (!await launchUrl(uri)) {
      await Clipboard.setData(ClipboardData(text: value));
      if (messenger != null && context.mounted) {
        AppSnackBar.info(context, tr('Copied {value}', {'value': value}));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Column(
      children: [
        InkWell(
          onTap: () => _open(context),
          onLongPress: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              AppSnackBar.info(context, tr('Copied {value}', {'value': value}));
            }
          },
          child: Padding(
            padding: EdgeInsets.all(sizing.cardPadding),
            child: Row(
              children: [
                Icon(icon, size: sizing.iconSm, color: AppColors.primary),
                SizedBox(width: sizing.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(label), style: sizing.text.cardTitle),
                      SizedBox(height: sizing.spacingXxs * 0.5),
                      Text(
                        value,
                        style: sizing.text.bodySmall.copyWith(
                          color: AppColors.primaryDeep,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: sizing.spacingXxs * 0.5),
                      Text(tr(note), style: sizing.text.metaLabel),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: sizing.iconSm,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sizing.cardPadding),
            child: Container(
              height: sizing.hairline,
              color: AppColors.dividerFaint,
            ),
          ),
      ],
    );
  }
}
