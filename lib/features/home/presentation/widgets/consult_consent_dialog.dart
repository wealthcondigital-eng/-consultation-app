import 'package:flutter/material.dart';

import '../../../../core/l10n/tr.dart';
import '../../../../core/responsive/app_sizing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_checkbox.dart';

/// Which consultation the patient is consenting to, and the terms of each.
enum ConsultConsent {
  video(
    title: 'Video consultation',
    icon: Icons.video_call_rounded,
    points: [
      'I consent to a video consultation with a registered medical '
          'practitioner through this app.',
      'I understand that the session may be recorded or shared only with my '
          'explicit consent.',
      'I give that consent: my audio or video call will be recorded on my '
          'own phone, and a compressed copy will be stored securely so that '
          'my doctor and I can watch or listen to it later in the app.',
      'I understand that my video and personal information will be handled '
          'confidentially and in accordance with applicable privacy '
          'guidelines.',
      'I will give accurate and complete information about my health, '
          'current medicines and allergies, so the doctor can advise me '
          'safely.',
      'I understand that a video consultation has limits, and the doctor may '
          'advise an in-person visit, tests or a specialist if needed.',
      'I understand that any prescription is issued at the doctor’s '
          'discretion and as permitted by law.',
      'I will join from a private place with a stable internet connection. '
          'A poor connection may affect the consultation.',
      'This service is not for emergencies. In an emergency I will call 112 '
          'or go to the nearest hospital.',
    ],
    acceptance:
        'I have read and understood all the points above, and I give my '
        'consent to the video consultation.',
  ),
  anonymous(
    title: 'Anonymous consultation',
    icon: Icons.privacy_tip_rounded,
    points: [
      'I understand that anonymous consultations do not include '
          'prescriptions for medicines or drugs.',
      'I understand that anonymous consultations are available only for '
          'eligible psychological counselling services.',
      'I will use my code name, and I will not share my real name, phone '
          'number or other details that identify me during the session.',
      'I understand that the doctor will not see my name, phone number or '
          'photo.',
      'I will describe my concern honestly, as it is the only information '
          'the doctor has before answering.',
      'I understand that if my concern needs an examination, tests or '
          'medicines, the doctor may advise a regular consultation instead.',
      'This service is not for emergencies or crisis situations. If I am at '
          'risk of harming myself or others, I will call 112 or Tele-MANAS '
          'on 14416.',
    ],
    acceptance:
        'I have read and understood all the points above, and I give my '
        'consent to the anonymous consultation.',
  );

  const ConsultConsent({
    required this.title,
    required this.icon,
    required this.points,
    required this.acceptance,
  });

  final String title;
  final IconData icon;

  /// The terms, one per point, in the order they are read.
  final List<String> points;

  /// The checkbox's own words: consent to everything above it.
  final String acceptance;

  /// The card's own colours, so the popup reads as the next step of the card
  /// that was tapped.
  AccentPalette get accent => switch (this) {
    ConsultConsent.video => AppColors.consultAccent,
    ConsultConsent.anonymous => AppColors.anonymousAccent,
  };
}

/// The terms a patient accepts before either kind of consultation.
///
/// Shown every time. The checkbox and I agree sit after the last point, and
/// the checkbox only unlocks once the patient has scrolled to the end — then
/// I agree only once it is ticked. What is being agreed to has to be read,
/// not tapped past.
class ConsultConsentDialog extends StatefulWidget {
  const ConsultConsentDialog({super.key, required this.consent});

  final ConsultConsent consent;

  /// The terms' scroll view, for tests that scroll it.
  static const Key scrollKey = ValueKey('consult-consent-scroll');

  /// True when the patient read to the end, ticked the box and agreed.
  static Future<bool> show(BuildContext context, ConsultConsent consent) async {
    final agreed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.45),
      builder: (_) => ConsultConsentDialog(consent: consent),
    );

    if (agreed == true) _agreedAt[consent] = DateTime.now();
    return agreed ?? false;
  }

  /// When each consent was last given, in this run of the app.
  static final Map<ConsultConsent, DateTime> _agreedAt = {};

  /// Forgets every consent, so each test starts from a patient who has not
  /// agreed to anything.
  @visibleForTesting
  static void resetConsents() => _agreedAt.clear();

  /// How long an "I agree" covers the flow it was given in. Long enough to
  /// pick a doctor and a slot after agreeing on the home screen, short enough
  /// that a consultation tomorrow asks again.
  static const Duration _consentLasts = Duration(minutes: 10);

  /// Asks unless [consent] was given moments ago.
  ///
  /// For the ways into a consultation that do not start at the home cards —
  /// a doctor's profile, the doctor list, "Consult again". Every one of them
  /// leads to a recorded call, so every one of them has to have asked; the
  /// window only spares someone who agreed on the home card a second popup a
  /// few taps later.
  static Future<bool> ensure(
    BuildContext context,
    ConsultConsent consent,
  ) async {
    final at = _agreedAt[consent];
    if (at != null && DateTime.now().difference(at) < _consentLasts) {
      return true;
    }
    return show(context, consent);
  }

  @override
  State<ConsultConsentDialog> createState() => _ConsultConsentDialogState();
}

class _ConsultConsentDialogState extends State<ConsultConsentDialog> {
  final ScrollController _scroll = ScrollController();

  bool _readToEnd = false;
  bool _accepted = false;

  /// Scrolled back to the top of the terms. The hint shows here — on opening,
  /// and again whenever someone scrolls back up before agreeing — and gets
  /// out of the way while the text in between is being read.
  bool _atTop = true;

  /// The terms run past the popup, so there is something to scroll to.
  bool _overflows = false;

  bool get _showHint => _overflows && _atTop && !_accepted;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // Terms short enough to fit without scrolling are read to the end as
    // soon as they are on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !_scroll.hasClients) return;

    final position = _scroll.position;
    final readToEnd =
        _readToEnd || position.pixels >= position.maxScrollExtent - 24;
    final atTop = position.pixels <= 8;
    final overflows = position.maxScrollExtent > 24;

    if (readToEnd != _readToEnd ||
        atTop != _atTop ||
        overflows != _overflows) {
      setState(() {
        // Once reached, the end stays reached: scrolling back up to re-read
        // a point does not lock the box again.
        _readToEnd = readToEnd;
        _atTop = atTop;
        _overflows = overflows;
      });
    }
  }

  void _toEnd() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final consent = widget.consent;
    final accent = consent.accent;
    final radius = BorderRadius.circular(sizing.radiusMd);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: EdgeInsets.symmetric(
        horizontal: sizing.screenPaddingH * 1.5,
        vertical: sizing.spacingXl,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(sizing.r(24)),
      ),
      clipBehavior: Clip.antiAlias,
      // A compact card rather than most of the screen. Both sets of terms
      // run past it, so each popup scrolls and shows the hint.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.58,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              consent: consent,
              onClose: () => Navigator.of(context).pop(false),
            ),
            Flexible(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    key: ConsultConsentDialog.scrollKey,
                    controller: _scroll,
                    padding: EdgeInsets.all(sizing.cardPaddingLarge),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          tr('Please read all the points below carefully.'),
                          style: sizing.text.helperText,
                        ),
                        SizedBox(height: sizing.spacingMd),
                        for (final (index, point)
                            in consent.points.indexed) ...[
                          if (index > 0) SizedBox(height: sizing.spacingSm),
                          _Point(
                            number: index + 1,
                            text: point,
                            accent: accent,
                          ),
                        ],
                        SizedBox(height: sizing.spacingLg),
                        Divider(
                          height: sizing.hairline,
                          color: AppColors.border,
                        ),
                        SizedBox(height: sizing.spacingMd),
                        AppCheckbox(
                          value: _accepted,
                          enabled: _readToEnd,
                          // The popup's own accent, so the tick matches the
                          // I agree button below it in both consultations.
                          activeColor: accent.icon,
                          onChanged: (value) =>
                              setState(() => _accepted = value),
                          semanticLabel: consent.acceptance,
                          label: Text(
                            tr(consent.acceptance),
                            style: sizing.text.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              color: _readToEnd
                                  ? AppColors.textPrimary
                                  : AppColors.textTertiary,
                            ),
                          ),
                        ),
                        SizedBox(height: sizing.spacingLg),
                        SizedBox(
                          height: sizing.buttonHeight,
                          child: FilledButton(
                            // Only once the box is ticked.
                            onPressed: _accepted
                                ? () => Navigator.of(context).pop(true)
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent.icon,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.border,
                              disabledForegroundColor: AppColors.textTertiary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: radius,
                              ),
                            ),
                            child: Text(
                              tr('I agree'),
                              style: sizing.text.buttonLabel.copyWith(
                                color: _accepted
                                    ? Colors.white
                                    : AppColors.textTertiary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: sizing.spacingXs),
                        SizedBox(
                          height: sizing.buttonHeight,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: TextButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: radius,
                              ),
                            ),
                            child: Text(
                              tr('Cancel'),
                              style: sizing.text.buttonLabel.copyWith(
                                color: AppColors.textLabel,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // At the top and not yet agreed: a fade over the cut-off
                  // text and a nudge that also takes them to the end. Back
                  // again whenever they scroll up to the top before agreeing.
                  if (_showHint)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _ScrollHint(onTap: _toEnd),
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

class _Header extends StatelessWidget {
  const _Header({required this.consent, required this.onClose});

  final ConsultConsent consent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;
    final accent = consent.accent;

    return Container(
      color: accent.surface,
      padding: EdgeInsets.fromLTRB(
        sizing.cardPaddingLarge,
        sizing.spacingMd,
        sizing.spacingXs,
        sizing.spacingMd,
      ),
      child: Row(
        children: [
          Container(
            width: sizing.r(48),
            height: sizing.r(48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.icon,
              borderRadius: BorderRadius.circular(sizing.radiusMd),
            ),
            child: Icon(consent.icon, size: sizing.r(26), color: Colors.white),
          ),
          SizedBox(width: sizing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(consent.title),
                  style: sizing.text.cardTitleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent.onSurface,
                  ),
                ),
                Text(
                  tr('Terms and consent'),
                  style: sizing.text.helperText.copyWith(
                    color: accent.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: tr('Cancel'),
            icon: Icon(
              Icons.close_rounded,
              size: sizing.iconMd,
              color: accent.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// One numbered term.
class _Point extends StatelessWidget {
  const _Point({
    required this.number,
    required this.text,
    required this.accent,
  });

  final int number;
  final String text;
  final AccentPalette accent;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: sizing.r(24),
          height: sizing.r(24),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.surface,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: sizing.text.badgeLabel.copyWith(
              color: accent.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(width: sizing.spacingSm),
        Expanded(
          child: Text(
            tr(text),
            style: sizing.text.bodySmall.copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// "Scroll to read all terms", over a fade at the bottom of the list.
class _ScrollHint extends StatelessWidget {
  const _ScrollHint({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sizing = context.sizing;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surface.withValues(alpha: 0), AppColors.surface],
          stops: const [0, 0.55],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          sizing.spacingMd,
          sizing.spacingXl,
          sizing.spacingMd,
          sizing.spacingMd,
        ),
        child: Center(
          child: Material(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(sizing.radiusPill),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(sizing.radiusPill),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: sizing.spacingMd,
                  vertical: sizing.spacingXs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flexible: on a narrow phone, or in Hindi, the label
                    // shortens rather than pushing the arrow off the pill.
                    Flexible(
                      child: Text(
                        tr('Scroll to read all terms'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: sizing.text.badgeLabel.copyWith(
                          color: AppColors.surface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: sizing.spacingXxs),
                    Icon(
                      Icons.keyboard_double_arrow_down_rounded,
                      size: sizing.iconSm,
                      color: AppColors.surface,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
