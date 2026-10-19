import 'hi/hi.dart';
import 'language_controller.dart';

/// The active language's strings.
///
/// Swapped by `LanguageController`, which then rebuilds the whole tree — the
/// same way the colour palette is swapped for dark mode.
class AppStrings {
  const AppStrings._();

  static AppLanguage _language = AppLanguage.english;
  static AppLanguage get language => _language;

  static void use(AppLanguage language) => _language = language;

  static Map<String, String> get _table => switch (_language) {
    AppLanguage.english => const {},
    AppLanguage.hindi => hindiStrings,
  };

  static String lookup(String english) => _table[english] ?? english;
}

/// Translates [english] into the active language.
///
/// **The English text is the key.** Wrapping a string is the whole job —
/// `Text('Consult Now')` becomes `Text(tr('Consult Now'))` — and a string with
/// no translation yet simply stays English rather than failing. That also
/// makes it safe to wrap text whose value is only known at run time (an enum's
/// label, say): if the table has it, it is translated; if not, it is shown as
/// it came.
///
/// Values go in `{braces}`, filled from [args]:
/// `tr('Updating · {percent}%', {'percent': 42})`. The translation must keep
/// the same placeholders, in whatever order the language needs them.
String tr(String english, [Map<String, Object?> args = const {}]) {
  var text = AppStrings.lookup(english);
  for (final entry in args.entries) {
    text = text.replaceAll('{${entry.key}}', '${entry.value}');
  }
  return text;
}
