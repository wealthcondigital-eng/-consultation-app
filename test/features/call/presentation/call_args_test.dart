import 'package:consultation_app/features/call/presentation/screens/call_screen.dart';
import 'package:consultation_app/features/consultation/domain/entities/consultation_mode.dart';
import 'package:consultation_app/features/consultation/domain/entities/live_consultation.dart';
import 'package:consultation_app/features/doctors/domain/entities/doctor.dart';
import 'package:flutter_test/flutter_test.dart';

/// The consultation as each end of it is served.
///
/// `isCaller` is the API's answer to "which end is this device", and the patient
/// is the side that dials — see `ConsultationsService.toJson`. Both fixtures
/// carry the *same* doctor and the same patient name, because that is exactly
/// the situation the bug lived in: one record, two readers, and a screen that
/// labelled itself from the doctor either way.
LiveConsultation _consultation({
  required bool isCaller,
  bool isAnonymous = false,
  String patientName = 'Rahul Sharma',
}) {
  return LiveConsultation(
    id: 'consultation-1',
    status: LiveConsultationStatus.accepted,
    mode: ConsultationMode.audio,
    channelId: 'consult-abc',
    peerId: isCaller ? 'patient-consultation-1' : 'doctor-consultation-1',
    isCaller: isCaller,
    patientName: patientName,
    isAnonymous: isAnonymous,
    doctor: const Doctor(
      id: 'doctor-1',
      name: 'Dr. Amit Verma',
      speciality: 'Cardiologist',
      yearsOfExperience: 15,
      rating: 4.8,
      consultationFee: 700,
      isVerified: true,
    ),
  );
}

void main() {
  group('CallArgs.fromConsultation', () {
    test('the patient is shown the doctor', () {
      final args = CallArgs.fromConsultation(_consultation(isCaller: true));

      expect(args.displayName, 'Dr. Amit Verma');
      expect(args.displaySubtitle, 'Cardiologist');
      expect(args.peerInitials, 'AV');
    });

    test('the doctor is shown the patient, not themselves', () {
      final args = CallArgs.fromConsultation(_consultation(isCaller: false));

      // The bug: both ends read the consultation's doctor, so a doctor spent
      // the call looking at their own name — in the header and, on an audio
      // call, in 24pt under their own initial.
      expect(args.displayName, 'Rahul Sharma');
      expect(args.displayName, isNot('Dr. Amit Verma'));
      expect(args.displaySubtitle, 'Patient');
      expect(args.peerInitials, 'RS');
    });

    test('an anonymous patient is named by their alias and nothing more', () {
      final args = CallArgs.fromConsultation(
        _consultation(
          isCaller: false,
          isAnonymous: true,
          patientName: 'Patient Hawk',
        ),
      );

      expect(args.displayName, 'Patient Hawk');
      expect(args.displaySubtitle, 'Anonymous patient');
    });

    test('the two ends never label themselves the same way', () {
      final patientSide = CallArgs.fromConsultation(
        _consultation(isCaller: true),
      );
      final doctorSide = CallArgs.fromConsultation(
        _consultation(isCaller: false),
      );

      // The invariant, stated once: whatever the record says, the two devices
      // must name *each other*. Both showing one name is the failure mode.
      expect(patientSide.displayName, isNot(doctorSide.displayName));
      expect(patientSide.peerId, isNot(doctorSide.peerId));
      expect(patientSide.isCaller, isNot(doctorSide.isCaller));
    });

    test('a call opened outside the instant flow falls back to the doctor', () {
      const args = CallArgs(
        doctor: Doctor(
          id: 'doctor-1',
          name: 'Dr. Sunita Rao',
          speciality: 'Pediatrician',
          yearsOfExperience: 12,
          rating: 4.9,
          consultationFee: 600,
        ),
        mode: ConsultationMode.video,
        channelId: 'consult-xyz',
      );

      expect(args.displayName, 'Dr. Sunita Rao');
      expect(args.displaySubtitle, 'Pediatrician');
      expect(args.peerInitials, 'SR');
    });

    test('a consultation with no doctor yet still has a name to show', () {
      final searching = LiveConsultation(
        id: 'consultation-2',
        status: LiveConsultationStatus.searching,
        mode: ConsultationMode.video,
        channelId: 'consult-def',
        peerId: 'patient-consultation-2',
        isCaller: true,
        patientName: 'Rahul Sharma',
      );

      final args = CallArgs.fromConsultation(searching);

      // The stand-in doctor, rather than an empty header. The call runs on the
      // channel, not on this.
      expect(args.displayName, 'Consultation');
      expect(args.peerInitials, isNotEmpty);
    });
  });
}
