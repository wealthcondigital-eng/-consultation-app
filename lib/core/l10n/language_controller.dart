import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tr.dart';

/// The languages the app is written in. English is the source; every other
/// language is a table keyed by the English text (see `tr`).
enum AppLanguage {
  english('en', 'English', 'English'),
  hindi('hi', 'Hindi', 'हिन्दी');

  const AppLanguage(this.code, this.englishName, this.nativeName);

  final String code;

  /// `Hindi` — how the language is named in English.
  final String englishName;

  /// `हिन्दी` — how the language names itself, which is what a person
  /// looking for their own language recognises.
  final String nativeName;

  Locale get locale => Locale(code);
}

/// Which language the app speaks, saved on the device.
///
/// Like the theme, a property of the phone in somebody's hand rather than of
/// their account — a family sharing one phone shares one language.
class LanguageController extends ChangeNotifier {
  LanguageController() {
    AppStrings.use(_language);
  }

  static const _key = 'app_language';

  AppLanguage _language = AppLanguage.english;
  AppLanguage get language => _language;

  /// Reads the saved choice. Awaited before `runApp`, so the first frame is in
  /// the right language.
  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_key);
      _language = AppLanguage.values.firstWhere(
        (language) => language.code == code,
        orElse: () => AppLanguage.english,
      );
    } catch (_) {
      _language = AppLanguage.english;
    }
    AppStrings.use(_language);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    AppStrings.use(language);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, language.code);
    } catch (_) {
      // The language still changed; it just will not be remembered.
    }
  }
}
