/// A language a consultation can be held in.
///
/// The list is deliberately short and hard-coded: it mirrors what the
/// on-call panel actually supports today.
enum ConsultLanguage {
  english('English', 'English', 'A'),
  hindi('Hindi', 'हिन्दी', 'अ'),
  marathi('Marathi', 'मराठी', 'म'),
  gujarati('Gujarati', 'ગુજરાતી', 'ગ'),
  bengali('Bengali', 'বাংলা', 'ব'),
  tamil('Tamil', 'தமிழ்', 'த'),
  telugu('Telugu', 'తెలుగు', 'త'),
  kannada('Kannada', 'ಕನ್ನಡ', 'ಕ');

  const ConsultLanguage(this.label, this.nativeName, this.glyph);

  /// The English name — also what is sent to the API.
  final String label;

  /// How the language writes its own name, which is what its speakers look
  /// for in a list.
  final String nativeName;

  /// One letter of the script, for the tile's badge.
  final String glyph;
}
