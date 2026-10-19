import 'package:consultation_app/app/app.dart';
import 'package:consultation_app/app/router/app_routes.dart';
import 'package:consultation_app/core/di/injector.dart';
import 'package:consultation_app/core/di/service_locator.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:consultation_app/features/doctors/presentation/screens/doctor_list_screen.dart';
import 'package:consultation_app/features/payment/data/datasources/payment_remote_data_source.dart';
import 'package:consultation_app/features/payment/domain/entities/payment_method.dart';
import 'package:consultation_app/features/payment/presentation/screens/payment_screen.dart';
import 'package:consultation_app/features/payment/presentation/widgets/payment_method_tile.dart';
import 'package:consultation_app/features/payment/presentation/widgets/upi_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _doctor = Doctor(
  id: 'amit-verma',
  name: 'Dr. Amit Verma',
  speciality: 'Senior Cardiologist',
  yearsOfExperience: 15,
  rating: 4.9,
  consultationFee: 800,
);

/// Screens the payment page must lay out cleanly on, smallest to largest.
const _devices = <String, Size>{
  'iPhone SE (320x568)': Size(320, 568),
  'Pixel 4a (393x851)': Size(393, 851),
  'iPhone 16 Pro design frame (402x874)': Size(402, 874),
  'iPad Mini (744x1133)': Size(744, 1133),
  'iPad Pro landscape (1366x1024)': Size(1366, 1024),
};

Future<void> _openPayment(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const TeleconsultApp(
      initialRoute: AppRoutes.payment,
      initialRouteArguments: PaymentArgs(doctor: _doctor),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _upiField() => find.descendant(
  of: find.byType(UpiDetails),
  matching: find.byType(TextField),
);

Finder _payButton() => find.widgetWithText(FilledButton, 'Pay ₹850');

void main() {
  setUp(() {
    sl.reset();
    configureDependencies();
  });

  group('PaymentScreen', () {
    for (final entry in _devices.entries) {
      testWidgets('lays out without overflow on ${entry.key}', (tester) async {
        await _openPayment(tester, entry.value);

        expect(tester.takeException(), isNull);
        expect(find.text('Payment'), findsOneWidget);
        expect(find.text('Dr. Amit Verma'), findsOneWidget);
        expect(find.text('Senior Cardiologist'), findsOneWidget);
        expect(find.text('Video Consultation'), findsOneWidget);
        expect(find.text('Fee Breakdown'), findsOneWidget);
        expect(find.text('₹800'), findsOneWidget);
        expect(find.text('₹50'), findsOneWidget);
        expect(find.text('₹850'), findsOneWidget);
        expect(find.text('Select Payment Method'), findsOneWidget);
        // The list builds lazily, so the lower tiles may be off-screen on a
        // short device — their count is asserted separately below.
        expect(find.byType(PaymentMethodTile), findsAtLeastNWidgets(1));
        expect(
          find.text('Secured by RazorPay • 256-bit encryption'),
          findsOneWidget,
        );
        expect(_payButton(), findsOneWidget);
      });
    }

    testWidgets('offers every payment method', (tester) async {
      await _openPayment(tester, const Size(402, 874));

      expect(find.byType(PaymentMethodTile), findsNWidgets(3));
      for (final method in PaymentMethod.values) {
        expect(find.text(method.label), findsOneWidget);
      }
    });

    testWidgets('opens with UPI selected and its details showing', (
      tester,
    ) async {
      await _openPayment(tester, const Size(402, 874));

      expect(find.byType(UpiDetails), findsOneWidget);
      expect(find.text('ENTER UPI ID'), findsOneWidget);
      expect(find.text('Or pay using popular apps:'), findsOneWidget);
      for (final app in UpiApp.values) {
        expect(find.text(app.label), findsOneWidget);
      }
    });

    testWidgets('choosing another method hides the UPI details', (
      tester,
    ) async {
      await _openPayment(tester, const Size(402, 874));

      await tester.tap(find.text(PaymentMethod.card.label));
      await tester.pumpAndSettle();

      expect(find.byType(UpiDetails), findsNothing);
    });

    testWidgets('Pay is blocked until a valid UPI ID is entered', (
      tester,
    ) async {
      await _openPayment(tester, const Size(402, 874));

      FilledButton payButton() => tester.widget<FilledButton>(_payButton());

      expect(payButton().onPressed, isNull);

      await tester.enterText(_upiField(), 'amit.verma');
      await tester.pump();
      expect(payButton().onPressed, isNull);

      await tester.enterText(_upiField(), 'amit.verma@okaxis');
      await tester.pump();
      expect(payButton().onPressed, isNotNull);
    });

    testWidgets('a method that needs no extra detail can pay straight away', (
      tester,
    ) async {
      await _openPayment(tester, const Size(402, 874));

      await tester.tap(find.text(PaymentMethod.netBanking.label));
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(_payButton()).onPressed, isNotNull);
    });

    testWidgets('verifying a UPI ID shows the account holder', (tester) async {
      await _openPayment(tester, const Size(402, 874));

      await tester.enterText(_upiField(), 'amit.verma@okaxis');
      await tester.pump();

      await tester.tap(find.text('Verify'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Amit Verma'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
    });

    testWidgets('an unknown UPI ID reports the failure', (tester) async {
      await _openPayment(tester, const Size(402, 874));

      await tester.enterText(
        _upiField(),
        'someone${FakePaymentRemoteDataSource.unknownHandle}',
      );
      await tester.pump();

      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.text('We could not find that UPI ID.'), findsOneWidget);
      expect(find.text('Verified'), findsNothing);
    });

    testWidgets('editing after verifying invalidates it', (tester) async {
      await _openPayment(tester, const Size(402, 874));

      await tester.enterText(_upiField(), 'amit.verma@okaxis');
      await tester.pump();
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();
      expect(find.text('Verified'), findsOneWidget);

      await tester.enterText(_upiField(), 'amit.verma@ybl');
      await tester.pump();

      expect(find.text('Verified'), findsNothing);
      expect(find.text('Verify'), findsOneWidget);
    });

    testWidgets('paying shows progress then confirms', (tester) async {
      await _openPayment(tester, const Size(402, 874));

      await tester.enterText(_upiField(), 'amit.verma@okaxis');
      await tester.pump();

      await tester.tap(_payButton());
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Bounded pumps: the confirmation screen starts its own auto-advance.
      // Two jumps after the transition so the replaced route is disposed.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Payment successful'), findsOneWidget);
      expect(
        find.text(
          '₹850 paid for a video consultation '
          'with Dr. Amit Verma.',
        ),
        findsOneWidget,
      );
      // Paying again by going back must not be possible.
      expect(_payButton(), findsNothing);
    });

    testWidgets('an immediate consult asks for payment before ringing anyone', (
      tester,
    ) async {
      // This test asserted the opposite until the hole it described was found:
      // the instant flow picked a doctor, picked the call type, and rang them
      // without charging for it. Only consultations booked for later were ever
      // paid for, so the quickest way to get a free consultation was to ask for
      // one *now* — and the reasoning written here, that a checkout between a
      // patient and a doctor who is free defeats the point of the flow, is what
      // kept it that way.
      //
      // Payment first, then the phone rings. Which is also what makes the
      // consultation attributable: `PaymentsService.attachPaymentFor` joins the
      // payment to the consultation once matching files it.
      addTearDown(() => tester.pumpWidget(const SizedBox.shrink()));

      tester.view
        ..physicalSize = const Size(402, 874)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const TeleconsultApp(
          initialRoute: AppRoutes.doctorList,
          initialRouteArguments: DoctorListArgs(instantOnly: true),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Book Appointment').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Video Consultation'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      // The bill, not the waiting room. Nobody's phone is ringing yet.
      expect(find.text('Fee Breakdown'), findsOneWidget);
      expect(find.text('Finding you the best doctor...'), findsNothing);
    });
  });
}
