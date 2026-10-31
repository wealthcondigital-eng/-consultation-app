import 'package:consultation_app/features/doctors/domain/entities/speciality.dart';
import 'package:consultation_app/features/home/presentation/widgets/speciality_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every speciality has a picture that draws', (tester) async {
    for (final symbol in SpecialitySymbol.values) {
      // The file is bundled — a missing one would be a blank circle on home.
      final svg = await rootBundle.loadString(
        'assets/specialities/${symbol.assetName}.svg',
      );
      expect(svg, contains('<svg'), reason: symbol.name);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: SpecialityArt(symbol: symbol, size: 52)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: symbol.name);
    }
  });

  test('names find the right picture, longest match first', () {
    SpecialitySymbol of(String name) => SpecialitySymbol.forName(name);

    expect(of('Stress Management'), SpecialitySymbol.mentalHealth);
    expect(of('Clinical Psychology'), SpecialitySymbol.mentalHealth);
    expect(of('Internal Medicine'), SpecialitySymbol.general);
    expect(of('Cardiology'), SpecialitySymbol.cardiology);
    expect(of('Dentistry'), SpecialitySymbol.dentistry);
    expect(of('Paediatrics'), SpecialitySymbol.paediatrics);
    expect(of('Dermatology'), SpecialitySymbol.dermatology);
    // `neurology` contains `uro`; it is still the brain, not the kidney.
    expect(of('Neurology'), SpecialitySymbol.neurology);
    expect(of('Urology'), SpecialitySymbol.kidney);
    expect(of('Nephrology'), SpecialitySymbol.kidney);
    // `gastroenterology` contains `ent`; it is still the stomach.
    expect(of('Gastroenterology'), SpecialitySymbol.gastro);
    expect(of('ENT (Otorhinolaryngology)'), SpecialitySymbol.ent);
    expect(of('Ophthalmology'), SpecialitySymbol.ophthalmology);
    expect(of('Pulmonology'), SpecialitySymbol.pulmonology);
    expect(of('Orthopaedics'), SpecialitySymbol.orthopaedics);
    expect(of('Physiotherapy'), SpecialitySymbol.orthopaedics);
    expect(of('Gynaecology & Obstetrics'), SpecialitySymbol.gynaecology);
    expect(of('Diabetology'), SpecialitySymbol.diabetes);
    expect(of('Endocrinology'), SpecialitySymbol.diabetes);
    expect(of('Oncology'), SpecialitySymbol.other);
  });
}
