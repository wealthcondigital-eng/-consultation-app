/// Bundled asset paths. Referencing these instead of raw strings means a
/// renamed file breaks at one place rather than at every call site.
class AppAssets {
  const AppAssets._();

  static const String _icons = 'assets/icons';

  /// Google's official "G" mark, as published in their sign-in branding
  /// guidelines. Do not recolour or redraw it — their terms require the
  /// supplied artwork.
  static const String googleLogo = '$_icons/google.svg';
}
