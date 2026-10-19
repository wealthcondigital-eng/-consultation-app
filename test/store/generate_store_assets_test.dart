// Generates the Google Play store graphics from the app itself: the 512px
// icon, the 1024x500 feature graphic, and phone screenshots of real screens
// (on the app's built-in demo data), each in a branded frame with a caption.
//
// Not a test of behaviour, and skipped in an ordinary `flutter test`. Run it
// to (re)generate everything into `store_assets/`:
//
//   flutter test test/store/generate_store_assets_test.dart --dart-define=STORE_ASSETS=true
//   node tool/png_strip_alpha.js store_assets/*.png store_assets/*/[0-9]*.png
//
// The second step matters: Play refuses a feature graphic or screenshot with
// an alpha channel, and Flutter renders RGBA.
//
// Screens render with the real Roboto and Material Icons fonts from the
// Flutter SDK, so text and icons look as they do on a phone rather than as the
// test font's boxes.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/core/theme/app_colors.dart';
import 'package:consultation_app/core/widgets/app_logo.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:consultation_app/features/doctors/presentation/screens/doctor_detail_screen.dart';
import 'package:consultation_app/features/doctors/presentation/screens/doctor_list_screen.dart';
import 'package:consultation_app/features/scheduling/presentation/screens/schedule_consultation_screen.dart';
import 'package:consultation_app/features/scheduling/presentation/widgets/schedule_date_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool _enabled = bool.fromEnvironment('STORE_ASSETS');

const String _out = 'store_assets';

/// One set of screenshots: where it goes, the image size, and how wide the app
/// is laid out — so a tablet shot shows the tablet layout, not a stretched
/// phone.
class _Device {
  const _Device(
    this.folder,
    this.canvas,
    this.logicalWidth, {
    Size? screen,
    this.frameWidth = 740,
  }) : screen = screen ?? canvas;

  final String folder;

  /// The finished image Play receives.
  final Size canvas;
  final double logicalWidth;

  /// The app screen captured inside it. A phone is taller than the 9:16
  /// canvas (9:19.5, like current Android phones), so it reads as a phone
  /// rather than a squat rectangle.
  final Size screen;

  /// How wide the screen is drawn in the frame, in units of a 1080-wide
  /// canvas.
  final double frameWidth;
}

const _devices = <_Device>[
  // A typical Android phone width — the layout most patients see.
  _Device(
    'phone',
    Size(1080, 1920),
    400,
    screen: Size(1080, 2340),
    frameWidth: 660,
  ),
  // Play's 7-inch tablet slot: a 600dp-wide portrait tablet.
  _Device('tablet_7in', Size(1440, 2560), 600),
  // Play's 10-inch tablet slot: an 800dp-wide portrait tablet.
  _Device('tablet_10in', Size(1440, 2560), 800),
];

const _doctor = Doctor(
  id: 'amit-verma',
  name: 'Dr. Amit Verma',
  speciality: 'Senior Cardiologist',
  yearsOfExperience: 15,
  rating: 4.9,
  consultationFee: 800,
  audioConsultationFee: 600,
  isVerified: true,
  isAvailableNow: true,
  registrationNumber: 'MH-2011-04871',
);

/// One screenshot: the screen to open, and the caption over it.
class _Shot {
  const _Shot(
    this.file,
    this.route,
    this.headline,
    this.subline, [
    this.args,
    this.prepare,
  ]);

  final String file;
  final String route;
  final Object? args;
  final String headline;
  final String subline;

  /// Taps the screen into the state worth showing, after it has loaded.
  final Future<void> Function(WidgetTester tester)? prepare;
}

const _shots = <_Shot>[
  _Shot(
    '01_home',
    AppRoutes.home,
    'See a doctor\nfrom home',
    'Video and voice consultations, now or later',
  ),
  _Shot(
    '02_doctors',
    AppRoutes.doctorList,
    'Choose from\nverified doctors',
    'Every registration is checked before they consult',
    DoctorListArgs(),
  ),
  _Shot(
    '03_doctor_profile',
    AppRoutes.doctorDetail,
    'Know your doctor\nbefore you call',
    'Experience, languages, fees and reviews',
    DoctorDetailArgs(doctor: _doctor),
  ),
  _Shot(
    '04_book_slot',
    AppRoutes.scheduleConsultation,
    'Book a time\nthat suits you',
    'Pick a day and slot — get reminders before it starts',
    ScheduleConsultationArgs(doctor: _doctor, mode: ConsultationMode.video),
    _pickTomorrowMorning,
  ),
  _Shot(
    '05_anonymous',
    AppRoutes.anonymousBooking,
    'Consult privately\nunder a code name',
    'The doctor sees only what you choose to share',
  ),
  _Shot(
    '06_appointments',
    AppRoutes.patientAppointments,
    'All your consultations\nin one place',
    'Upcoming, past and receipts',
  ),
  _Shot(
    '07_medical_history',
    AppRoutes.medicalHistory,
    'Your health records,\nalways with you',
    'Share history and reports with your doctor',
  ),
  _Shot(
    '08_doctor_home',
    AppRoutes.doctorHome,
    'For doctors: go online,\nget consultations',
    'Calls ring even when the app is closed',
  ),
];

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) {
    throw StateError('FLUTTER_ROOT is not set — run this with `flutter test`.');
  }
  final dir = '$root/bin/cache/artifacts/material_fonts';

  final roboto = FontLoader('Roboto');
  for (final weight in ['light', 'regular', 'medium', 'bold', 'black']) {
    final file = File('$dir/roboto-$weight.ttf');
    if (file.existsSync()) {
      roboto.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  // Emoji (the greeting's wave): Windows' colour emoji font, added to the
  // same family so a glyph Roboto lacks falls back to it.
  await roboto.load();

  // Emoji (the greeting's wave): Windows' colour emoji font, registered under
  // the family names the text engine falls back to for emoji.
  final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
  if (emoji.existsSync()) {
    for (final family in [
      'Noto Color Emoji',
      'Segoe UI Emoji',
      'Apple Color Emoji',
    ]) {
      await (FontLoader(family)..addFont(
            Future.value(ByteData.sublistView(emoji.readAsBytesSync())),
          ))
          .load();
    }
  }

  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          File('$dir/materialicons-regular.otf').readAsBytesSync(),
        ),
      ),
    );
  await icons.load();
}

/// Captures the [RepaintBoundary] keyed [key] at [pixelRatio] and writes it.
Future<Uint8List> _capture(
  WidgetTester tester,
  GlobalKey key,
  double pixelRatio,
  String path,
) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
    final file = File(path)..createSync(recursive: true);
    await file.writeAsBytes(bytes);
  });
  return bytes;
}

/// Lets the demo data arrive and entrance animations finish, without waiting
/// for screens that never settle (polls, pulsing rings).
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  setUpAll(() async {
    if (_enabled) await _loadFonts();
  });

  setUp(() {
    // Plugins with no implementation under test — preferences, push, call
    // ringing, connectivity — are not what is being pictured. Their absence
    // is swallowed so the screen around them still renders.
    SharedPreferences.setMockInitialValues({});
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception is MissingPluginException) return;
      original?.call(details);
    };
    addTearDown(() => FlutterError.onError = original);

    sl.reset();
    configureDependencies();
  });

  group('store assets', skip: !_enabled, () {
    testWidgets('app icon 512x512', (tester) async {
      tester.view
        ..physicalSize = const Size(512, 512)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: RepaintBoundary(
            key: key,
            // Square: Play applies its own rounded mask and shadow, and a
            // pre-rounded icon would show its corners inside Play's.
            child: const AppLogoTile(size: 512, radiusFactor: 0),
          ),
        ),
      );
      await tester.pump();
      await _capture(tester, key, 1, '$_out/icon_512.png');
    });

    testWidgets('feature graphic 1024x500', (tester) async {
      tester.view
        ..physicalSize = const Size(1024, 500)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            // Material, so the text is not drawn with the debug underline.
            child: const Material(
              type: MaterialType.transparency,
              child: _FeatureGraphic(),
            ),
          ),
        ),
      );
      await tester.pump();
      await _capture(tester, key, 1, '$_out/feature_graphic_1024x500.png');
    });

    for (final device in _devices) {
      for (final shot in _shots) {
        testWidgets('${device.folder} ${shot.file}', (tester) async {
          // 1. The screen itself, laid out at the device's logical width and
          //    captured at the canvas's pixel width.
          final ratio = device.screen.width / device.logicalWidth;
          tester.view
            ..physicalSize = device.screen
            ..devicePixelRatio = ratio;
          addTearDown(tester.view.reset);

          final screenKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: screenKey,
              child: TeleconsultApp(
                initialRoute: shot.route,
                initialRouteArguments: shot.args,
              ),
            ),
          );
          await _settle(tester);
          if (shot.prepare != null) {
            await shot.prepare!(tester);
            await _settle(tester);
          }

          final raw = await _capture(
            tester,
            screenKey,
            ratio,
            '$_out/${device.folder}/raw/${shot.file}.png',
          );

          // Tear the app down so its timers stop before the next pump.
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));

          // 2. The framed version: brand background, caption, and the screen
          //    on a rounded "phone".
          tester.view
            ..physicalSize = device.canvas
            ..devicePixelRatio = 1;
          final framedKey = GlobalKey();
          final image = MemoryImage(raw);

          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              home: RepaintBoundary(
                key: framedKey,
                child: _Framed(
                  canvas: device.canvas,
                  screen: device.screen,
                  frameWidth: device.frameWidth,
                  image: image,
                  headline: shot.headline,
                  subline: shot.subline,
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => precacheImage(image, tester.element(find.byType(_Framed))),
          );
          await tester.pump();

          await _capture(
            tester,
            framedKey,
            1,
            '$_out/${device.folder}/${shot.file}.png',
          );
        });
      }
    }
  });
}

/// The caption at the top, the screen below on a rounded panel. Designed at
/// 1080 wide and scaled by [canvas]'s width, so a tablet canvas keeps the same
/// proportions.
class _Framed extends StatelessWidget {
  const _Framed({
    required this.canvas,
    required this.screen,
    required this.frameWidth,
    required this.image,
    required this.headline,
    required this.subline,
  });

  final Size canvas;
  final Size screen;
  final double frameWidth;
  final ImageProvider image;
  final String headline;
  final String subline;

  @override
  Widget build(BuildContext context) {
    final s = canvas.width / 1080;
    final screenWidth = frameWidth * s;

    // Material, so captions are not drawn with the debug "no Material"
    // underline.
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: canvas.width,
        height: canvas.height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1B7B80), Color(0xFF0F4F53)],
          ),
        ),
        child: Column(
          children: [
            SizedBox(height: 90 * s),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 76 * s,
                height: 1.12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5 * s,
              ),
            ),
            SizedBox(height: 28 * s),
            Text(
              subline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 38 * s,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            SizedBox(height: 56 * s),
            // The whole screen, at exactly its own 9:16, inside a thin bezel —
            // nothing cropped and no gap under it.
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(54 * s),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x66000000),
                    blurRadius: 60 * s,
                    offset: Offset(0, 24 * s),
                  ),
                ],
              ),
              padding: EdgeInsets.all(14 * s),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40 * s),
                child: SizedBox(
                  width: screenWidth,
                  height: screenWidth * screen.height / screen.width,
                  child: Image(image: image, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1024 x 500: the mark, the name and the promise, on the brand teal.
class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1024,
      height: 500,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B7B80), Color(0xFF0F4F53)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 90),
      child: Row(
        children: [
          Container(
            width: 230,
            height: 230,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(56),
            ),
            alignment: Alignment.center,
            child: AppLogoMark(size: 150, color: AppColors.onBrand),
          ),
          const SizedBox(width: 70),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teleconsult',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 78,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'See a verified doctor online —\nby video or voice call.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 36,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                    color: Color(0xE6FFFFFF),
                  ),
                ),
                SizedBox(height: 22),
                Text(
                  'Care. Anytime. Anywhere.',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9FE3E0),
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tomorrow, 10:30 — a slot that exists whatever time of day this runs, so the
/// booking shows a chosen time and a live Confirm button.
Future<void> _pickTomorrowMorning(WidgetTester tester) async {
  final days = find.descendant(
    of: find.byType(ScheduleDateStrip),
    matching: find.byType(InkWell),
  );
  await tester.tap(days.at(1));
  await _settle(tester);

  final slot = find.text('10:30');
  await tester.ensureVisible(slot);
  await _settle(tester);
  await tester.tap(slot);
}
