import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app's colour palette, in a light and a dark variant.
///
/// Built around Neslife's dark teal — `#1B7B80` into `#246D74`, the two stops
/// of [brandGradient]. Every brand token below is derived from that pair, so
/// the gradient on a nav bar, the fill of a primary button and the tint behind
/// a badge all read as one colour family rather than three near-misses.
///
/// The names are semantic rather than literal (`primaryDeep`, not `teal900`):
/// what a colour is *for* survives a rebrand — and a theme switch. Each token
/// is a getter onto the active [AppPalette], which `ThemeController` swaps
/// before rebuilding the tree, so no screen branches on brightness itself.
class AppColors {
  const AppColors._();

  static AppPalette _palette = AppPalette.light;

  /// The palette every token currently reads from.
  static AppPalette get palette => _palette;

  /// Swaps the palette. Only `ThemeController` should call this, and it
  /// rebuilds the whole tree straight after.
  static void use(AppPalette palette) => _palette = palette;

  static bool get isDark => _palette.isDark;

  // --- Brand ---------------------------------------------------------------

  /// Gradient start — the brand's own teal. Filled buttons, outlines, accents.
  static Color get primary => _palette.primary;

  /// Gradient end. A shade cooler and darker than [primary].
  static Color get primaryEnd => _palette.primaryEnd;

  /// High-emphasis teal for an action or heading on a card. Deep on light,
  /// pale on dark — it is the "strong teal text" role either way.
  static Color get primaryDeep => _palette.primaryDeep;

  /// Inline links and small accents.
  static Color get primaryVivid => _palette.primaryVivid;

  /// The outline of a selected option.
  static Color get primarySoft => _palette.primarySoft;

  /// The brand ramp, start to end.
  static List<Color> get brandGradient => [
    _palette.gradientStart,
    _palette.gradientEnd,
  ];

  /// The same ramp as a [LinearGradient], for a fill.
  static LinearGradient get brandSweep => LinearGradient(
    colors: brandGradient,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// And horizontally, for a bar or a strip where a diagonal would clip.
  static LinearGradient get brandBar => LinearGradient(
    colors: brandGradient,
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // --- On the brand gradient -----------------------------------------------

  /// Headings and glyphs on a brand-gradient surface. White in both themes.
  static const Color onBrand = Colors.white;

  /// Supporting copy on the gradient.
  static const Color onBrandMuted = Color(0xD1FFFFFF);

  /// Fill of a control sitting on the gradient.
  static const Color onBrandSurface = Color(0x29FFFFFF);

  /// Hairline around such a control.
  static const Color onBrandBorder = Color(0x3DFFFFFF);

  // --- Status --------------------------------------------------------------

  static Color get successSurface => _palette.successSurface;
  static Color get success => _palette.success;
  static Color get badgeSurface => _palette.badgeSurface;
  static Color get successStrong => _palette.successStrong;
  static Color get danger => _palette.danger;
  static Color get dangerSurface => _palette.dangerSurface;
  static Color get warning => _palette.warning;
  static Color get warningSurface => _palette.warningSurface;
  static Color get ratingStar => _palette.ratingStar;

  // --- Surfaces ------------------------------------------------------------

  static Color get primarySurface => _palette.primarySurface;
  static Color get infoSurface => _palette.infoSurface;

  /// Cards, sheets, dialogs. White on light.
  static Color get surface => _palette.surface;

  /// Filled inputs, icon buttons and neutral (tertiary) buttons.
  static Color get surfaceMuted => _palette.surfaceMuted;

  /// Input borders, dividers and hairlines.
  static Color get border => _palette.border;

  /// A rule between rows inside a card.
  static Color get dividerFaint => _palette.dividerFaint;

  /// Page background behind a card-based layout.
  static Color get canvas => _palette.canvas;

  /// Behind an avatar or profile glyph.
  static Color get avatarSurface => _palette.avatarSurface;

  /// The ground a call screen and any other full-bleed dark surface sits on.
  static Color get inkDeep => _palette.inkDeep;

  // --- Text ----------------------------------------------------------------

  static Color get textPrimary => _palette.textPrimary;
  static Color get textLabel => _palette.textLabel;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textTertiary => _palette.textTertiary;

  // --- Accents -------------------------------------------------------------

  /// The brand-teal "Consult Now" call to action.
  static AccentPalette get consultAccent => _palette.consultAccent;

  /// The "Anonymous Consult" call to action — a violet of its own, so privacy
  /// can be found without reading.
  static AccentPalette get anonymousAccent => _palette.anonymousAccent;

  // --- System bars ---------------------------------------------------------

  /// Status-bar style for a screen whose top is [canvas] or [surface]: dark
  /// icons on light, light icons on dark.
  static SystemUiOverlayStyle get overlayOnCanvas =>
      isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

  /// Icon brightness for a navigation bar coloured [surface] or [canvas].
  static Brightness get navIconBrightness =>
      isDark ? Brightness.light : Brightness.dark;
}

/// One complete set of colours. [light] is the original palette, unchanged;
/// [dark] keeps the same roles on a deep teal-grey ground.
@immutable
class AppPalette {
  const AppPalette({
    required this.isDark,
    required this.primary,
    required this.primaryEnd,
    required this.primaryDeep,
    required this.primaryVivid,
    required this.primarySoft,
    required this.gradientStart,
    required this.gradientEnd,
    required this.successSurface,
    required this.success,
    required this.badgeSurface,
    required this.successStrong,
    required this.danger,
    required this.dangerSurface,
    required this.warning,
    required this.warningSurface,
    required this.ratingStar,
    required this.primarySurface,
    required this.infoSurface,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.dividerFaint,
    required this.canvas,
    required this.avatarSurface,
    required this.inkDeep,
    required this.textPrimary,
    required this.textLabel,
    required this.textSecondary,
    required this.textTertiary,
    required this.consultAccent,
    required this.anonymousAccent,
  });

  final bool isDark;
  final Color primary;
  final Color primaryEnd;
  final Color primaryDeep;
  final Color primaryVivid;
  final Color primarySoft;
  final Color gradientStart;
  final Color gradientEnd;
  final Color successSurface;
  final Color success;
  final Color badgeSurface;
  final Color successStrong;
  final Color danger;
  final Color dangerSurface;
  final Color warning;
  final Color warningSurface;
  final Color ratingStar;
  final Color primarySurface;
  final Color infoSurface;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color dividerFaint;
  final Color canvas;
  final Color avatarSurface;
  final Color inkDeep;
  final Color textPrimary;
  final Color textLabel;
  final Color textSecondary;
  final Color textTertiary;
  final AccentPalette consultAccent;
  final AccentPalette anonymousAccent;

  static const light = AppPalette(
    isDark: false,
    primary: Color(0xFF1B7B80),
    primaryEnd: Color(0xFF246D74),
    primaryDeep: Color(0xFF12565A),
    primaryVivid: Color(0xFF1B7B80),
    primarySoft: Color(0xFF3A9BA0),
    gradientStart: Color(0xFF1B7B80),
    gradientEnd: Color(0xFF246D74),
    successSurface: Color(0xFFECFDF5),
    success: Color(0xFF059669),
    badgeSurface: Color(0xFFDCFCE7),
    successStrong: Color(0xFF16A34A),
    danger: Color(0xFFDC2626),
    dangerSurface: Color(0xFFFEF2F2),
    warning: Color(0xFFD97706),
    warningSurface: Color(0xFFFFFBEB),
    ratingStar: Color(0xFFF59E0B),
    primarySurface: Color(0xFFE7F2F2),
    infoSurface: Color(0xFFD2E7E8),
    surface: Colors.white,
    surfaceMuted: Color(0xFFF6F9F9),
    border: Color(0xFFE3E9EA),
    dividerFaint: Color(0xFFF0F5F5),
    canvas: Color(0xFFF5F8F8),
    avatarSurface: Color(0xFFD7EBEC),
    inkDeep: Color(0xFF0C2B2D),
    textPrimary: Color(0xFF10201F),
    textLabel: Color(0xFF33474A),
    textSecondary: Color(0xFF64797C),
    textTertiary: Color(0xFF95A6A8),
    consultAccent: AccentPalette(
      surface: Color(0xFFE7F2F2),
      border: Color(0xFFB4D9DB),
      icon: Color(0xFF1B7B80),
      onSurface: Color(0xFF12565A),
    ),
    anonymousAccent: AccentPalette(
      surface: Color(0xFFF1ECFB),
      border: Color(0xFFD9CEF4),
      icon: Color(0xFF6D4AC4),
      onSurface: Color(0xFF4B2E93),
    ),
  );

  static const dark = AppPalette(
    isDark: true,
    // A brighter teal: the brand value sinks into a dark ground.
    primary: Color(0xFF34A3A9),
    primaryEnd: Color(0xFF2A8A90),
    primaryDeep: Color(0xFF8ED8DB),
    primaryVivid: Color(0xFF4FB8BE),
    primarySoft: Color(0xFF5FC2C7),
    // The header gradient stays the brand's own depth, so white on it keeps
    // its contrast.
    gradientStart: Color(0xFF176A6F),
    gradientEnd: Color(0xFF1D5A60),
    successSurface: Color(0xFF0E2B22),
    success: Color(0xFF34D399),
    badgeSurface: Color(0xFF113524),
    successStrong: Color(0xFF22C55E),
    danger: Color(0xFFF87171),
    dangerSurface: Color(0xFF341818),
    warning: Color(0xFFFBBF24),
    warningSurface: Color(0xFF33270E),
    ratingStar: Color(0xFFFBBF24),
    primarySurface: Color(0xFF122E2F),
    infoSurface: Color(0xFF163536),
    surface: Color(0xFF162021),
    surfaceMuted: Color(0xFF1D2A2B),
    border: Color(0xFF2B3B3C),
    dividerFaint: Color(0xFF213031),
    canvas: Color(0xFF0D1516),
    avatarSurface: Color(0xFF1F3A3B),
    inkDeep: Color(0xFF071718),
    textPrimary: Color(0xFFE6EFEF),
    textLabel: Color(0xFFC4D2D3),
    textSecondary: Color(0xFF95A9AB),
    textTertiary: Color(0xFF6D8284),
    consultAccent: AccentPalette(
      surface: Color(0xFF122E2F),
      border: Color(0xFF24504F),
      icon: Color(0xFF34A3A9),
      onSurface: Color(0xFF8ED8DB),
    ),
    anonymousAccent: AccentPalette(
      surface: Color(0xFF211A33),
      border: Color(0xFF3A2E5C),
      icon: Color(0xFF9B7FE6),
      onSurface: Color(0xFFCBB9F7),
    ),
  );
}

/// The four colours a tinted card needs, kept together so a card cannot be
/// built from a mismatched set.
@immutable
class AccentPalette {
  const AccentPalette({
    required this.surface,
    required this.border,
    required this.icon,
    required this.onSurface,
  });

  final Color surface;
  final Color border;

  /// Fill of the small icon badge.
  final Color icon;

  /// Title and body text on [surface].
  final Color onSurface;
}
