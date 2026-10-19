import 'package:flutter/widgets.dart';

import 'app_colors.dart';

/// The type scale, resolved for a screen size.
///
/// Font sizes are design pixels multiplied by the screen's text scale, so the
/// hierarchy holds together on a 320pt phone and on a tablet alike. Reach for
/// these via `context.textStyles` rather than constructing them directly.
@immutable
class AppTextStyles {
  const AppTextStyles({required this.scale});

  /// Multiplier applied to every design-pixel font size.
  final double scale;

  double _size(double designPx) => designPx * scale;

  /// The design specifies Inter. See `AppTheme.fontFamily` for how to bundle it.
  static const String? fontFamily = null;

  TextStyle get brandTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(36),
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  TextStyle get brandTagline => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(16),
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  TextStyle get headline => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(24),
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Title in the top bar.
  TextStyle get navTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(18),
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// The big question a screen asks — e.g. "Let's Get Started".
  TextStyle get screenTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(28),
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  /// The same role as [screenTitle] on a denser screen, e.g. above a form.
  TextStyle get screenTitleCompact => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(24),
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );

  TextStyle get screenSubtitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(14),
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  TextStyle get fieldLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(13),
    fontWeight: FontWeight.w600,
    color: AppColors.textLabel,
  );

  /// Supporting copy under a title, and field placeholders.
  TextStyle get helperText => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(13),
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  TextStyle get fieldPlaceholder => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(14),
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  TextStyle get fieldValue => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(14),
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  TextStyle get fieldAffix => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(14),
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// Opening paragraph that explains what a screen is asking for.
  TextStyle get leadParagraph => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(15),
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// Title of a large, standalone card.
  TextStyle get cardTitleLarge => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(18),
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// Body copy inside a card.
  TextStyle get cardBody => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(14),
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  /// A supporting note under a card title.
  TextStyle get cardNote => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(13),
    fontWeight: FontWeight.w500,
    color: AppColors.primaryVivid,
  );

  /// A small inline link, e.g. `Video Consultation`.
  TextStyle get linkSmall => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(12),
    fontWeight: FontWeight.w600,
    color: AppColors.primaryVivid,
  );

  /// The headline figure of a total.
  TextStyle get amountTotal => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(18),
    fontWeight: FontWeight.w800,
    color: AppColors.primaryVivid,
  );

  /// All-caps label above a compact input.
  TextStyle get inputLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(11),
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  /// Label on a filter or choice chip. The caller supplies the colour.
  TextStyle get chipLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(12),
    fontWeight: FontWeight.w600,
  );

  /// Primary line of a list row, and the figure it emphasises.
  TextStyle get listTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(15),
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// De-emphasised metadata on a list row, e.g. `15 yrs Exp`.
  TextStyle get metaLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(11),
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );

  /// Caption above a value, e.g. `Consultation Fee`.
  TextStyle get fieldCaption => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(11),
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  /// Label on a compact, in-card button.
  TextStyle get buttonLabelCompact => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(13),
    fontWeight: FontWeight.w600,
  );

  /// Text inside a status pill. The caller supplies the colour.
  TextStyle get badgeLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(12),
    fontWeight: FontWeight.w600,
  );

  /// Heading above a section of a scrolling page.
  TextStyle get sectionTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(16),
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// The "See All" link beside a [sectionTitle].
  TextStyle get sectionAction => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(12),
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  /// Title inside a card. Tinted cards recolour it.
  TextStyle get cardTitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(14),
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  TextStyle get cardSubtitle => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(11),
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Secondary line under a heading, e.g. "How can we help you today?".
  TextStyle get bodySmall => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(12),
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// Label under a speciality tile.
  TextStyle get tileLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(11),
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  /// The number in a rating pill.
  TextStyle get ratingValue => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(11),
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  /// Label under a bottom-navigation icon.
  TextStyle get navLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(10),
    fontWeight: FontWeight.w500,
  );

  /// A single digit in an OTP box.
  TextStyle get otpDigit => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(20),
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  /// "Resend OTP in" — the static half of the countdown line.
  TextStyle get countdownLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(13),
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  /// The ticking value, and the tappable "Resend OTP" it becomes.
  TextStyle get countdownValue => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(13),
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  /// The "OR" between two alternative actions.
  TextStyle get dividerLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(12),
    fontWeight: FontWeight.w600,
    color: AppColors.textTertiary,
  );

  /// Consent copy and legal small print. The generous line height keeps the
  /// multi-line consent paragraphs readable.
  TextStyle get legalBody => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(12),
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  TextStyle get legalLink => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(12),
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.primary,
    height: 1.5,
  );

  /// The compliance badge under a form's submit button.
  TextStyle get complianceBadge => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(11),
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );

  TextStyle get complianceNote => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(11),
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  TextStyle get legalFootnote => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(12),
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  TextStyle get error => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(12),
    fontWeight: FontWeight.w500,
    color: AppColors.danger,
  );

  TextStyle get body => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(15),
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  TextStyle get buttonLabel => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(15),
    fontWeight: FontWeight.w600,
  );

  TextStyle get caption => TextStyle(
    fontFamily: fontFamily,
    fontSize: _size(12),
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
  );
}
