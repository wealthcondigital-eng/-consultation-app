import '../../../../core/branding/app_brand.dart';

/// One heading and the text under it.
class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;

  /// Paragraphs. Split rather than one blob so the screen can space them
  /// without parsing blank lines out of a string.
  final List<String> body;
}

/// A policy document, as the app shows it.
///
/// The text below is **Neslife Research's own**, taken from
/// nesliferesearch.com — the parent company, whose policies govern this app.
/// The privacy policy, the terms and the cancellation and refund policy are the
/// site's, kept in the site's wording
/// so the two cannot say different things about the same company; the
/// data-protection notice is the app's, because the site has none and the app
/// handles health data the site never sees.
///
/// Sourced 24 September 2026, when both site documents read "Last updated
/// June 22, 2026". When the site is revised, these have to be revised with
/// it — there is no fetch at runtime, deliberately: a policy that loads over
/// the network is a policy that is blank on a train.
class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.updatedOn,
    required this.intro,
    required this.sections,
  });

  final String title;

  /// `22 June 2026` — shown under the title, because a policy with no date on
  /// it is one nobody can tell they have already read.
  final String updatedOn;

  final String intro;

  final List<LegalSection> sections;

  /// India's Digital Personal Data Protection Act notice.
  ///
  /// **The app's own, not the website's.** The site's privacy policy covers a
  /// website selling courses; this covers a service that carries a person's
  /// conditions, medication and consultations. The Act asks for an itemised
  /// notice of what is collected and why, at the point of collection, and a
  /// policy written about page visits does not answer it.
  static const LegalDocument dpdp = LegalDocument(
    title: 'Data Protection Notice',
    updatedOn: '25 September 2026',
    intro:
        'This notice explains what personal data ${AppBrand.name} collects, '
        'why, and what you can do about it, as required by the Digital '
        'Personal Data Protection Act, 2023. It sits alongside the Neslife '
        'Research privacy policy, and covers the health information this app '
        'handles that the website does not.',
    sections: [
      LegalSection(
        heading: 'What we collect',
        body: [
          'Your mobile number, which is how you sign in and the only thing we '
              'need to create an account.',
          'What you choose to add to your profile: your name, date of birth, '
              'gender, and any medical history or reports you upload.',
          'A record of each consultation — who it was with, when, how long it '
              'ran, what it cost, and the reason you gave for it.',
        ],
      ),
      LegalSection(
        heading: 'Why we collect it',
        body: [
          'To connect you to a doctor and to give that doctor the context they '
              'need to advise you safely.',
          'To take payment for a consultation and to show you what you have '
              'paid.',
          'To meet the record-keeping obligations that apply to medical '
              'consultations.',
        ],
      ),
      LegalSection(
        heading: 'Who sees it',
        body: [
          'The doctor you consult sees your name, the reason you gave, and any '
              'history you have recorded. On an anonymous consultation they see '
              'an alias and the reason, and nothing else.',
          'No doctor can see a consultation you had with a different doctor.',
          'We do not sell your data, and we do not share it for advertising.',
        ],
      ),
      LegalSection(
        heading: 'How long we keep it',
        body: [
          'Your profile for as long as your account exists.',
          'Consultation records for the period medical record-keeping rules '
              'require, after which they are removed.',
          'When you delete your account, your profile, name and contact '
              'details, your photo, the reports you uploaded and your medical '
              'history are erased immediately, and every device signed in to '
              'the account is signed out.',
          'The date, length and cost of past consultations are kept, stripped '
              'of your name and everything else that identifies you. They are '
              'the doctor\'s clinical and billing record too, so they remain.',
          'You can sign up again with the same number straight after a '
              'deletion. It opens a new, empty account.',
        ],
      ),
      LegalSection(
        heading: 'Your rights',
        body: [
          'You can see and correct what is on your profile at any time from the '
              'Profile tab.',
          'You can withdraw consent by deleting your account, which is in this '
              'menu.',
          'You can ask us what we hold about you by writing to the grievance '
              'officer on the Contact Us page.',
        ],
      ),
    ],
  );

  /// Neslife Research's privacy policy, as published at
  /// nesliferesearch.com/privacy-policy.
  ///
  /// Condensed to its operative parts — the definitions block and the cookie
  /// taxonomy are three screens of a document nobody scrolls on a phone, and
  /// this app sets no cookies. Nothing that grants a right or states an
  /// obligation has been dropped. The full text is on the website, and the last
  /// section says so.
  static const LegalDocument privacyPolicy = LegalDocument(
    title: 'Privacy Policy',
    updatedOn: '22 June 2026',
    intro:
        'This Privacy Policy describes our policies and procedures on the '
        'collection, use and disclosure of your information when you use the '
        'Service, and tells you about your privacy rights and how the law '
        'protects you. The Company is ${AppBrand.legalEntity}, Mumbai City, '
        'Maharashtra.',
    sections: [
      LegalSection(
        heading: 'Personal data we collect',
        body: [
          'Email address.',
          'First name and last name.',
          'Phone number.',
          'Usage data, collected automatically: your device\'s IP address, the '
              'pages you visit, the time and date of your visit, unique device '
              'identifiers and other diagnostic data. On a mobile device this '
              'may also include the device type, its unique ID and its '
              'operating system.',
        ],
      ),
      LegalSection(
        heading: 'How we use it',
        body: [
          'To provide and maintain the Service, and to monitor its use.',
          'To manage your account and your registration as a user.',
          'For the performance of a contract — the purchase of the products or '
              'services you have asked for.',
          'To contact you by email, telephone, SMS or push notification about '
              'updates and security notices related to what you use.',
          'To manage your requests, and to evaluate and improve the Service.',
        ],
      ),
      LegalSection(
        heading: 'Who we share it with',
        body: [
          'Service providers who process data on our behalf, to monitor and '
              'analyse the use of the Service and to contact you.',
          'Affiliates, who are required to honour this policy.',
          'In connection with a merger, sale of assets, financing or '
              'acquisition of all or part of our business.',
          'With your consent, for any other purpose.',
        ],
      ),
      LegalSection(
        heading: 'How long we keep it',
        body: [
          'We retain your personal data only for as long as is necessary for '
              'the purposes set out in this policy, and to comply with our '
              'legal obligations, resolve disputes and enforce our agreements.',
          'Usage data is generally retained for a shorter period, except where '
              'it is used to strengthen security or improve the Service, or we '
              'are legally obliged to keep it longer.',
        ],
      ),
      LegalSection(
        heading: 'Deleting your data',
        body: [
          'You have the right to delete, or to ask us to help you delete, the '
              'personal data we have collected about you.',
          'You can update, amend or delete your information at any time from '
              'your account settings, and you can delete the account itself '
              'from the Legal & Support menu in this app.',
          'We may need to retain certain information where we have a legal '
              'obligation or lawful basis to do so.',
        ],
      ),
      LegalSection(
        heading: 'Security',
        body: [
          'The security of your personal data is important to us, but no method '
              'of transmission over the internet or of electronic storage is '
              '100% secure. While we strive to use commercially acceptable '
              'means to protect it, we cannot guarantee its absolute security.',
        ],
      ),
      LegalSection(
        heading: 'Transfers',
        body: [
          'Your information is processed at the Company\'s operating offices '
              'and anywhere else the parties involved are located, which may be '
              'outside your jurisdiction. We take all steps reasonably '
              'necessary to ensure your data is treated securely and in '
              'accordance with this policy.',
        ],
      ),
      LegalSection(
        heading: 'Children',
        body: [
          'The website Service does not address anyone under 13 and we do not '
              'knowingly collect data from them.',
          'This app is stricter: it is for adults, and an account cannot be '
              'created by anyone under 18. A minor may be consulted for, with '
              'an identified adult present, as the telemedicine guidelines '
              'require.',
        ],
      ),
      LegalSection(
        heading: 'Changes, and the full text',
        body: [
          'We may update this policy from time to time. We will post the new '
              'policy and update the date at the top of it, and let you know by '
              'email or a prominent notice before the change takes effect.',
          'This is the operative text. The policy in full is published at '
              'nesliferesearch.com/privacy-policy.',
          'Questions about this policy: admin@nesliferesearch.com.',
        ],
      ),
    ],
  );

  /// Neslife Research's terms, as published at
  /// nesliferesearch.com/terms-and-conditions, plus the clauses a medical
  /// consultation needs and a website does not.
  ///
  /// The emergency warning leads, and is the app's. The site sells courses;
  /// nothing on it has to tell a reader to put the phone down and call an
  /// ambulance, and this does.
  static const LegalDocument termsAndConditions = LegalDocument(
    title: 'Terms & Conditions',
    updatedOn: '22 June 2026',
    intro:
        'In these Terms, "we", "us" and "our" mean ${AppBrand.legalEntity}, '
        'whose registered and operational office is A-1107, Kailash Business '
        'Park, V S Road, Parksite, Vikhroli West, Mumbai - 400079. "You" means '
        'anyone using this app or purchasing from us. Please read the section '
        'on emergencies first — it is the one that matters most.',
    sections: [
      LegalSection(
        heading: 'This is not emergency care',
        body: [
          'Do not use this app for a medical emergency. If you are having chest '
              'pain, difficulty breathing, severe bleeding, or you think someone '
              'may be having a stroke, call your local emergency number or go to '
              'the nearest hospital.',
          'A teleconsultation cannot examine you, cannot admit you, and cannot '
              'reach you in time.',
        ],
      ),
      LegalSection(
        heading: 'What the service is',
        body: [
          'We connect you to registered medical practitioners for a remote '
              'consultation. The doctor advises you; we do not.',
          'Every doctor on the platform has had their council registration and '
              'qualifications checked before being listed, and their '
              'registration number is shown on their profile.',
        ],
      ),
      LegalSection(
        heading: 'Consultations and prescriptions',
        body: [
          'What a doctor advises is a matter between you and them, and follows '
              'the same professional rules as an in-person visit.',
          'A doctor may decline to prescribe remotely and may ask to see you in '
              'person. That is a clinical judgement, and not something we '
              'override.',
        ],
      ),
      LegalSection(
        heading: 'Accuracy of information',
        body: [
          'The content of this app is subject to change without notice.',
          'Neither we nor any third party provides any warranty or guarantee as '
              'to the accuracy, timeliness, performance, completeness or '
              'suitability of the information and materials found here for any '
              'particular purpose. You acknowledge that they may contain '
              'inaccuracies or errors, and we expressly exclude liability for '
              'those to the fullest extent permitted by law.',
        ],
      ),
      LegalSection(
        heading: 'Use at your own risk',
        body: [
          'Your use of any information or materials in this app is entirely at '
              'your own risk, for which we shall not be liable. It is your own '
              'responsibility to ensure that any products, services or '
              'information available through it meet your requirements.',
        ],
      ),
      LegalSection(
        heading: 'Intellectual property',
        body: [
          'This app contains material owned by or licensed to us, including its '
              'design, layout, look, appearance and graphics. Reproduction is '
              'prohibited other than in accordance with the copyright notice '
              'that forms part of these terms.',
          'All trademarks reproduced here which are not our property, or '
              'licensed to us, are acknowledged.',
          'Unauthorised use of information provided by us may give rise to a '
              'claim for damages and/or be a criminal offence.',
        ],
      ),
      LegalSection(
        heading: 'Payments, cancellation and refunds',
        body: [
          'The fee is shown before you pay and is charged when you book.',
          'If a consultation does not take place because the doctor did not '
              'join, the fee is refunded in full to the original payment '
              'method. A consultation you do not attend is not refunded.',
          'The Cancellation & Refund Policy, in the Legal & Support menu, sets '
              'this out in full.',
          'We are under no liability for any loss arising from the decline of '
              'authorisation for a transaction where the cardholder has '
              'exceeded the limit agreed with our acquiring bank.',
        ],
      ),
      LegalSection(
        heading: 'Your account',
        body: [
          'One account per mobile number, and you must be 18 or over to hold '
              'one. Do not share it: the consultation history on it is treated '
              'as one person\'s.',
          'You can delete your account at any time from the Legal & Support '
              'menu, and sign up again with the same number whenever you like.',
        ],
      ),
      LegalSection(
        heading: 'Governing law',
        body: [
          'Any dispute arising out of your use of this app, or any purchase or '
              'engagement with us, is subject to the laws of India.',
        ],
      ),
    ],
  );

  /// Neslife Research's cancellation and refund policy, as published at
  /// nesliferesearch.com/cancellation-and-refund, plus the refunds this app
  /// makes on its own.
  ///
  /// The site's policy is one sentence, and it leads here unchanged. It is
  /// about *requests*. What follows it is not a request: it is the money the
  /// server sends back unasked when nothing was delivered — no doctor answered,
  /// or the patient called the search off first — which the payment screens
  /// already promise and `PaymentFailureReason` already models. A policy that
  /// said "no refunds" over a screen saying "your refund is on its way" would
  /// be wrong in one place or the other.
  ///
  /// The site's page carries no date. The date here is the day it was copied.
  static const LegalDocument cancellationAndRefund = LegalDocument(
    title: 'Cancellation & Refund Policy',
    updatedOn: '25 September 2026',
    intro:
        'This policy is ${AppBrand.legalEntity}\'s, and applies to every '
        'payment made in this app.',
    sections: [
      LegalSection(
        heading: 'Cancellation and refunds',
        body: ['No cancellation or refund requests will be accepted.'],
      ),
      LegalSection(
        heading: 'When a consultation does not happen',
        body: [
          'If you pay for an instant consultation and no doctor answers, the '
              'fee is refunded automatically to your original payment method. '
              'You do not need to ask for it.',
          'If you call off the search before a doctor answers, the fee is '
              'refunded the same way, because no consultation took place.',
          'If a payment leaves your account but the booking could not be '
              'confirmed, the amount is either confirmed as a booking within a '
              'few minutes or released by your bank on its own. Please do not '
              'pay a second time while you wait.',
          'Refunds usually arrive in 5–7 working days, depending on your bank.',
          'A consultation that took place, or one you booked and did not '
              'attend, is not refunded.',
        ],
      ),
      LegalSection(
        heading: 'Contact information',
        body: [
          'For any questions regarding cancellations or refunds, please contact '
              'us:',
          'Email: ${SupportDetails.email}',
        ],
      ),
    ],
  );
}

/// How to reach a person.
///
/// Neslife Research's own published details — the registered office, the
/// mailbox and the number on nesliferesearch.com. The grievance address is the
/// one exception: the Act asks for a route for data complaints kept apart from
/// ordinary support, and the site publishes only one address, so this points at
/// the same mailbox until a separate one exists.
class SupportDetails {
  const SupportDetails._();

  /// The one support channel. Email only, by the business's decision
  /// (2026-10-13): no phone number is shown or dialled anywhere in the app.
  static const String email = 'admin@nesliferesearch.com';

  static const String hours = 'Monday to Saturday, 9:00 AM to 8:00 PM IST';

  static const String responseTime = 'We reply to email within one working day';

  static const List<String> address = [
    AppBrand.legalEntity,
    'A-1107, Kailash Business Park',
    'V S Road, Parksite, Vikhroli West',
    'Mumbai - 400079, Maharashtra, India',
  ];

  /// The DPDP Act asks for a named contact for data complaints, separate from
  /// ordinary support.
  static const String grievanceOfficer = 'Grievance Officer';
  static const String grievanceEmail = 'admin@nesliferesearch.com';
}
