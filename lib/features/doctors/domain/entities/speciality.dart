import '../../../../core/l10n/tr.dart';

/// A medical speciality a patient can browse doctors by.
class Speciality {
  const Speciality({
    required this.id,
    required this.name,
    required this.practitionerTitle,
    required this.symbol,
    this.listingTitle,
  });

  /// One derived from a patient's own history, where the only thing known is
  /// what the doctor's record calls their specialty — `Cardiology`, not
  /// `Cardiologist`.
  ///
  /// [id] is that string verbatim, because it is what the directory filters on
  /// (`GET /doctors?speciality=`). A prettier slug here would have to be
  /// translated back on the way out, and the tile would quietly return no
  /// doctors — which is what the app's hard-coded ids (`cardiology` against a
  /// record reading `Cardiology`) were already doing.
  factory Speciality.named(String name) {
    final trimmed = name.trim();

    return Speciality(
      id: trimmed,
      name: trimmed,
      practitionerTitle: trimmed,
      // "Cardiology doctors", not "Cardiologys". A specialty name is not a
      // practitioner title and cannot be pluralised into one.
      listingTitle: '$trimmed doctors',
      symbol: SpecialitySymbol.forName(trimmed),
    );
  }

  /// Overrides the naive plural of [practitionerTitle] where that would not
  /// read — `Cardiology doctors` rather than `Cardiologys`. Null for the
  /// app's own specialities, whose titles pluralise cleanly.
  final String? listingTitle;

  final String id;

  /// Short label for a tile, e.g. `Cardio`.
  final String name;

  /// What a doctor of this speciality is called, e.g. `Cardiologist`.
  final String practitionerTitle;

  /// Which glyph represents this speciality. Kept as a domain-level enum so
  /// the entity carries no Flutter types; the presentation layer maps it to an
  /// icon.
  final SpecialitySymbol symbol;

  /// Heading for the listing screen, e.g. `Cardiologists`.
  ///
  /// Naive pluralisation, which holds for every title the app ships itself. One
  /// built from a doctor's specialty carries its own, because `Cardiology` is
  /// not a practitioner title and does not pluralise into one.
  String get listingHeading {
    // A [Speciality.named] heading is built from the name, so it is translated
    // the same way — as a sentence with the name in it, not as a fixed string.
    if (listingTitle == '$name doctors') {
      return tr('{speciality} doctors', {'speciality': tr(name)});
    }
    return tr(listingTitle ?? '${practitionerTitle}s');
  }

  /// Placeholder for the listing's search box, e.g. `Search Cardiologist`.
  String get searchHint =>
      tr('Search {title}', {'title': tr(practitionerTitle)});
}

enum SpecialitySymbol {
  general,
  dentistry,
  cardiology,
  paediatrics,
  dermatology,
  neurology,

  /// Fallback for a speciality the app does not have a glyph for yet.
  other;

  /// The glyph for a specialty named by the backend.
  ///
  /// Matched on a substring rather than on equality, because the string is a
  /// doctor's own free-text specialty and reads `Paediatrics`, `Pediatric
  /// Surgery` or `Child Health` depending on who typed it. A miss is
  /// [SpecialitySymbol.other], which draws a neutral glyph — a wrong icon is
  /// worse than a generic one.
  static SpecialitySymbol forName(String name) {
    final needle = name.toLowerCase();

    bool has(String term) => needle.contains(term);

    if (has('cardio') || has('heart')) return SpecialitySymbol.cardiology;
    if (has('dent') || has('oral')) return SpecialitySymbol.dentistry;
    if (has('paedia') || has('pedia') || has('child')) {
      return SpecialitySymbol.paediatrics;
    }
    if (has('derma') || has('skin')) return SpecialitySymbol.dermatology;
    if (has('neuro') || has('nerve')) return SpecialitySymbol.neurology;
    if (has('general') || has('physician') || has('medicine')) {
      return SpecialitySymbol.general;
    }

    return SpecialitySymbol.other;
  }
}
