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
  general('general'),
  dentistry('dentistry'),
  cardiology('cardiology'),
  paediatrics('paediatrics'),
  dermatology('dermatology'),
  neurology('neurology'),

  /// Stress management, psychiatry, psychology.
  mentalHealth('mental_health'),

  /// Bones, joints, physiotherapy, sports injuries.
  orthopaedics('orthopaedics'),
  ophthalmology('ophthalmology'),
  ent('ent'),

  /// Lungs and breathing.
  pulmonology('pulmonology'),

  /// Stomach, gut and liver.
  gastro('gastro'),
  gynaecology('gynaecology'),

  /// Kidneys and urinary tract.
  kidney('kidney'),

  /// Diabetes and hormones.
  diabetes('diabetes'),

  /// Fallback for a speciality the app does not have a picture for yet.
  other('other');

  const SpecialitySymbol(this.assetName);

  /// The illustration's file in `assets/specialities/`, without `.svg`.
  final String assetName;

  /// The illustration for a specialty named by the backend.
  ///
  /// Matched on a substring rather than on equality, because the string is a
  /// doctor's own free-text specialty and reads `Paediatrics`, `Pediatric
  /// Surgery` or `Child Health` depending on who typed it. A miss is
  /// [SpecialitySymbol.other], which draws a neutral picture — a wrong one is
  /// worse than a generic one.
  ///
  /// **Order matters**: `neurology` contains `uro`, `gastroenterology`
  /// contains `ent`, so the longer names are tried first.
  static SpecialitySymbol forName(String name) {
    final needle = name.toLowerCase();

    bool has(String term) => needle.contains(term);

    // Before neurology, whose `neuro` would otherwise claim neuropsychiatry.
    if (has('stress') || has('psych') || has('mental') || has('counsel')) {
      return SpecialitySymbol.mentalHealth;
    }
    if (has('cardio') || has('heart') || has('vascular')) {
      return SpecialitySymbol.cardiology;
    }
    if (has('dent') || has('oral')) return SpecialitySymbol.dentistry;
    if (has('paedia') || has('pedia') || has('child')) {
      return SpecialitySymbol.paediatrics;
    }
    if (has('derma') || has('skin') || has('tricho') || has('cosmet')) {
      return SpecialitySymbol.dermatology;
    }
    if (has('neuro') || has('nerve')) return SpecialitySymbol.neurology;
    if (has('gastro') || has('hepat') || has('stomach') || has('digest')) {
      return SpecialitySymbol.gastro;
    }
    // A word on its own: `ent` also sits inside "gastroenterology".
    if (RegExp(r'\bent\b').hasMatch(needle) ||
        has('otorhin') ||
        has('ear, nose')) {
      return SpecialitySymbol.ent;
    }
    if (has('ophthal') || has('eye') || has('optom')) {
      return SpecialitySymbol.ophthalmology;
    }
    if (has('pulmo') || has('lung') || has('respir') || has('chest')) {
      return SpecialitySymbol.pulmonology;
    }
    if (has('ortho') ||
        has('bone') ||
        has('physio') ||
        has('rheuma') ||
        has('sports')) {
      return SpecialitySymbol.orthopaedics;
    }
    if (has('gyn') || has('obstet') || has('women')) {
      return SpecialitySymbol.gynaecology;
    }
    if (has('nephro') || has('uro') || has('kidney')) {
      return SpecialitySymbol.kidney;
    }
    if (has('diabet') || has('endocrin') || has('thyroid')) {
      return SpecialitySymbol.diabetes;
    }
    if (has('general') ||
        has('physician') ||
        has('medicine') ||
        has('family')) {
      return SpecialitySymbol.general;
    }

    return SpecialitySymbol.other;
  }
}
