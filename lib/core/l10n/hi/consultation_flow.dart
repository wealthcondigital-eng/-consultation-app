/// Hindi strings for this area of the app, keyed by the English text exactly
/// as it is passed to `tr()`. Keep placeholders like `{name}` unchanged.
///
/// Covers appointments (list, card, receipt), consultation (options, mode
/// sheet, doctor matching, incoming call banner, feedback), the anonymous
/// booking flow and scheduling.
const Map<String, String> hiConsultationFlow = {
  // --- Appointment status, kind, filter, payment ---------------------------
  'Confirmed': 'कन्फ़र्म',
  'Finding a doctor': 'डॉक्टर ढूँढ रहे हैं',
  'Ringing': 'घंटी बज रही है',
  'Accepted': 'स्वीकार किया',
  'In progress': 'चल रहा है',
  'Completed': 'पूरा हुआ',
  'Cancelled': 'रद्द',
  'No answer': 'जवाब नहीं मिला',
  'Paid': 'पेमेंट हो गया',
  'Payment failed': 'पेमेंट विफल',
  'Refunded': 'रिफ़ंड हुआ',
  'Payment pending': 'पेमेंट बाकी',
  'Instant': 'तुरंत',
  'Scheduled': 'शेड्यूल्ड',
  'Instant Consultation': 'तुरंत कंसल्टेशन',
  'Scheduled Consultation': 'शेड्यूल्ड कंसल्टेशन',
  'Upcoming': 'आने वाले',
  'Past': 'पिछले',
  'All': 'सभी',
  'All types': 'सभी प्रकार',
  'Card': 'कार्ड',
  'Net banking': 'नेट बैंकिंग',
  'Wallet': 'वॉलेट',
  '{seconds} sec': '{seconds} सेकंड',
  '{minutes} min': '{minutes} मिनट',
  '{hours} h {minutes} min': '{hours} घंटे {minutes} मिनट',

  // --- Consultation mode -----------------------------------------------------
  'Video Consultation': 'वीडियो कंसल्टेशन',
  'Video': 'वीडियो',
  'Face to face on a video call — best for anything the doctor should see.':
      'वीडियो कॉल पर आमने-सामने — जब डॉक्टर को कुछ दिखाना हो तो सबसे अच्छा।',
  'Video Call': 'वीडियो कॉल',
  'High-definition call': 'HD क्वालिटी कॉल',
  'Audio Consultation': 'ऑडियो कंसल्टेशन',
  'Audio': 'ऑडियो',
  'A voice call. Lighter on data and works on a weak connection.':
      'वॉइस कॉल। कम डेटा लगता है और कमज़ोर नेटवर्क पर भी चलता है।',
  'Voice Call': 'वॉइस कॉल',
  'Voice-only consultation': 'सिर्फ़ आवाज़ वाला कंसल्टेशन',
  'Audio Call': 'ऑडियो कॉल',

  // --- Appointments list -------------------------------------------------------
  'My Appointments': 'मेरे अपॉइंटमेंट',
  'Consultations': 'कंसल्टेशन',
  '{count} consultation': '{count} कंसल्टेशन',
  '{count} consultations': '{count} कंसल्टेशन',
  'No scheduled consultations': 'कोई शेड्यूल्ड कंसल्टेशन नहीं',
  'No instant consultations': 'कोई तुरंत कंसल्टेशन नहीं',
  'No consultations': 'कोई कंसल्टेशन नहीं',
  'Booked appointments will appear here.':
      'बुक किए गए अपॉइंटमेंट यहाँ दिखेंगे।',
  'Consultations started with Consult Now will appear here.':
      'अभी परामर्श लें से शुरू किए गए कंसल्टेशन यहाँ दिखेंगे।',
  'Try another filter.': 'कोई दूसरा फ़िल्टर आज़माएँ।',
  'Nothing coming up': 'आगे कुछ नहीं है',
  'No past consultations': 'कोई पिछला कंसल्टेशन नहीं',
  'No consultations yet': 'अभी तक कोई कंसल्टेशन नहीं',
  'Consultations you book will appear here.':
      'आपके बुक किए गए कंसल्टेशन यहाँ दिखेंगे।',
  'Consultations you take will appear here.':
      'आपके किए गए कंसल्टेशन यहाँ दिखेंगे।',
  'Consultation type': 'कंसल्टेशन का प्रकार',
  'Consultation done': 'कंसल्टेशन पूरा हुआ',
  'Not connected': 'कनेक्ट नहीं हुआ',
  'No charge': 'कोई शुल्क नहीं',
  'View bill': 'बिल देखें',
  'Rejoin call': 'कॉल में फिर जुड़ें',

  // --- Receipt -----------------------------------------------------------------
  'Consultation receipt': 'कंसल्टेशन रसीद',
  'Teleconsult receipt': 'Teleconsult रसीद',
  'Could not share the receipt.': 'रसीद शेयर नहीं हो सकी।',
  'Share receipt': 'रसीद शेयर करें',
  'Share bill only': 'सिर्फ़ बिल शेयर करें',
  'Just the bill — for insurance or reimbursement':
      'सिर्फ़ बिल — इंश्योरेंस या रीइम्बर्समेंट के लिए',
  'Share full screen': 'पूरी स्क्रीन शेयर करें',
  'Payment status and the bill together': 'पेमेंट स्टेटस और बिल एक साथ',
  'Receipt': 'रसीद',
  'Share': 'शेयर करें',
  'Share bill': 'बिल शेयर करें',
  'Payment successful': 'पेमेंट सफल',
  'Amount refunded': 'राशि रिफ़ंड हुई',
  'to {name}': '{name} को',
  'Consultation bill': 'कंसल्टेशन बिल',
  'Consultation details': 'कंसल्टेशन की जानकारी',
  'Type': 'प्रकार',
  'Mode': 'माध्यम',
  'Date & time': 'तारीख और समय',
  'Duration': 'अवधि',
  'Consultation': 'कंसल्टेशन',
  'Done': 'पूरा हुआ',
  'Bill summary': 'बिल सारांश',
  'Consultation fee': 'कंसल्टेशन फ़ीस',
  'Platform fee': 'प्लेटफ़ॉर्म फ़ीस',
  'Amount due': 'बकाया राशि',
  'Total paid': 'कुल भुगतान',
  'Payment details': 'पेमेंट की जानकारी',
  'Paid via': 'पेमेंट का तरीका',
  'Transaction ID': 'ट्रांज़ैक्शन ID',
  'Not available': 'उपलब्ध नहीं',
  'Paid on': 'पेमेंट की तारीख',
  'Reference ID': 'रेफ़रेंस ID',
  'This is a receipt for a teleconsultation fee. It is not a prescription and not a medical record.':
      'यह टेलीकंसल्टेशन फ़ीस की रसीद है। यह पर्चा या मेडिकल रिकॉर्ड नहीं है।',
  'Reg. No. not on record': 'रजि. नं. रिकॉर्ड में नहीं',
  'Reg. No. {number}': 'रजि. नं. {number}',
  '{label} copied': '{label} कॉपी हो गया',

  // --- Feedback ----------------------------------------------------------------
  'Your review could not be sent.': 'आपका रिव्यू नहीं भेजा जा सका।',
  'Thanks — your review is on their profile.':
      'धन्यवाद — आपका रिव्यू उनकी प्रोफ़ाइल पर दिख रहा है।',
  'Rate Your Experience': 'अपना अनुभव बताएँ',
  'Rate the Doctor': 'डॉक्टर को रेटिंग दें',
  'Call Quality': 'कॉल क्वालिटी',
  'The connection, not the doctor.': 'कनेक्शन की, डॉक्टर की नहीं।',
  'How was your experience?': 'आपका अनुभव कैसा रहा?',
  'Very Helpful': 'बहुत मददगार',
  'Good Listener': 'ध्यान से सुना',
  'Professional': 'प्रोफ़ेशनल',
  'Knowledgeable': 'जानकार',
  'Friendly': 'मिलनसार',
  'Write a review for other patients (optional)...':
      'दूसरे मरीज़ों के लिए रिव्यू लिखें (वैकल्पिक)...',
  'Your review appears on the doctor’s profile as “Verified patient”. Your name is never shown.':
      'आपका रिव्यू डॉक्टर की प्रोफ़ाइल पर “वेरिफ़ाइड मरीज़” के नाम से दिखता है। आपका नाम कभी नहीं दिखाया जाता।',
  'Sending…': 'भेज रहे हैं…',
  'Submit Feedback': 'फ़ीडबैक भेजें',
  'Skip': 'छोड़ें',
  'TYPE': 'प्रकार',
  'DURATION': 'अवधि',
  '{rating} star': '{rating} स्टार',
  '{rating} stars': '{rating} स्टार',

  // --- Consult options and mode sheet -----------------------------------------
  'Consult Now': 'अभी परामर्श लें',
  'Select your preferred consultation method. We will match you with certified medical experts.':
      'कंसल्टेशन का तरीका चुनें। हम आपको प्रमाणित डॉक्टरों से जोड़ेंगे।',
  'Retry': 'फिर कोशिश करें',
  'Connect instantly with the next available general physician for urgent symptoms, guidance, or prescriptions.':
      'अचानक हुई तकलीफ़, सलाह या पर्चे के लिए अगले उपलब्ध जनरल फ़िज़िशियन से तुरंत जुड़ें।',
  'Connect Now': 'अभी जुड़ें',
  'Schedule a detailed video call appointment with highly rated specialists or your family doctor at your convenience.':
      'अपनी सुविधा के समय टॉप रेटेड स्पेशलिस्ट या अपने फ़ैमिली डॉक्टर के साथ वीडियो कॉल अपॉइंटमेंट बुक करें।',
  'Book Appointment': 'अपॉइंटमेंट बुक करें',
  'Book slots for later today or tomorrow':
      'आज बाद में या कल के लिए स्लॉट बुक करें',
  'Estimated Wait: under a minute': 'अनुमानित इंतज़ार: एक मिनट से कम',
  'Estimated Wait: ~{minutes} min': 'अनुमानित इंतज़ार: ~{minutes} मिनट',
  'Estimated Wait: ~{minutes} mins': 'अनुमानित इंतज़ार: ~{minutes} मिनट',
  'How would you like to consult?': 'आप कैसे परामर्श लेना चाहेंगे?',
  'Choose a call type before selecting your doctor.':
      'डॉक्टर चुनने से पहले कॉल का प्रकार चुनें।',
  'with {name}': '{name} के साथ',

  // --- Doctor search and matching ---------------------------------------------
  'Searching available doctors': 'उपलब्ध डॉक्टर खोज रहे हैं',
  'Checking doctor availability': 'डॉक्टर की उपलब्धता देख रहे हैं',
  'Connecting securely': 'सुरक्षित रूप से जोड़ रहे हैं',
  'pending': 'बाकी',
  'active': 'चल रहा है',
  'done': 'पूरा',
  '1 doctor found': '1 डॉक्टर मिला',
  '{count} doctors found': '{count} डॉक्टर मिले',
  'No doctors available': 'कोई डॉक्टर उपलब्ध नहीं',
  'Search could not finish': 'खोज पूरी नहीं हो सकी',
  'Looking for a {title} who is free now.': 'अभी खाली {title} ढूँढ रहे हैं।',
  'Looking for a doctor who is free now.': 'अभी खाली डॉक्टर ढूँढ रहे हैं।',
  'Tap to see who can take your consultation.':
      'देखने के लिए टैप करें कि कौन आपका कंसल्टेशन ले सकता है।',
  'Nobody is online right now. Try again in a few minutes.':
      'अभी कोई ऑनलाइन नहीं है। कुछ मिनट बाद फिर कोशिश करें।',
  'Something went wrong. Please try again.':
      'कुछ गड़बड़ हो गई। कृपया फिर कोशिश करें।',
  'No doctors are available right now. Please try again shortly.':
      'अभी कोई डॉक्टर उपलब्ध नहीं है। कृपया थोड़ी देर बाद फिर कोशिश करें।',
  'No doctor was available. Please try again in a few minutes.':
      'कोई डॉक्टर उपलब्ध नहीं था। कृपया कुछ मिनट बाद फिर कोशिश करें।',
  'The consultation was cancelled.': 'कंसल्टेशन रद्द कर दिया गया।',
  'The consultation is no longer active.': 'यह कंसल्टेशन अब सक्रिय नहीं है।',
  'Consultations need a connection to the server.':
      'कंसल्टेशन के लिए सर्वर से कनेक्शन ज़रूरी है।',
  'Booking a slot is not available yet. You have not been charged — try an instant consultation instead.':
      'स्लॉट बुकिंग अभी उपलब्ध नहीं है। आपसे कोई पैसा नहीं लिया गया — इसकी जगह तुरंत कंसल्टेशन आज़माएँ।',
  'The doctor': 'डॉक्टर',
  'Search in the background': 'बैकग्राउंड में खोजें',
  'We will keep looking and tell you on your dashboard.':
      'हम खोजते रहेंगे और आपके डैशबोर्ड पर बताएँगे।',
  'Close': 'बंद करें',
  'Cancel': 'रद्द करें',
  'We could not connect you': 'हम आपको कनेक्ट नहीं कर सके',
  'Doctor found': 'डॉक्टर मिल गए',
  'Finding you the best doctor...':
      'आपके लिए सबसे अच्छे डॉक्टर ढूँढ रहे हैं...',
  '{name} is joining now': '{name} अभी जुड़ रहे हैं',
  'Your doctor': 'आपके डॉक्टर',
  'Please wait while we connect you to an available doctor':
      'कृपया रुकें, हम आपको उपलब्ध डॉक्टर से जोड़ रहे हैं',
  'Estimated time {time}': 'अनुमानित समय {time}',
  'That consultation could not be opened.': 'वह कंसल्टेशन खुल नहीं सका।',
  'Stop looking': 'खोजना बंद करें',
  'Dismiss': 'हटाएँ',
  'Cancel search': 'खोज रद्द करें',
  'See doctors': 'डॉक्टर देखें',
  'Try again': 'फिर कोशिश करें',

  // --- Incoming call banner ----------------------------------------------------
  'Incoming video consultation': 'वीडियो कंसल्टेशन आ रहा है',
  'Incoming audio consultation': 'ऑडियो कंसल्टेशन आ रहा है',
  '{name} · anonymous': '{name} · गुमनाम',
  'Decline': 'मना करें',
  'Accept': 'स्वीकार करें',

  // --- Anonymous booking -------------------------------------------------------
  'Anonymous Booking': 'गुमनाम बुकिंग',
  'Your real identity will not be shared': 'आपकी असली पहचान शेयर नहीं की जाएगी',
  'When': 'कब',
  'Now': 'अभी',
  'Book a slot': 'स्लॉट बुक करें',
  'Preferred Language': 'पसंदीदा भाषा',
  'Choose a language': 'भाषा चुनें',
  'We’ll connect you with a doctor who speaks it.':
      'हम आपको ऐसे डॉक्टर से जोड़ेंगे जो यह भाषा बोलते हैं।',
  'English': 'अंग्रेज़ी',
  'Hindi': 'हिंदी',
  'Marathi': 'मराठी',
  'Gujarati': 'गुजराती',
  'Bengali': 'बंगाली',
  'Tamil': 'तमिल',
  'Telugu': 'तेलुगु',
  'Kannada': 'कन्नड़',
  'Describe your concern': 'अपनी समस्या बताएँ',
  'Would like to discuss stress and anxiety management...':
      'तनाव और घबराहट से निपटने के बारे में बात करनी है...',
  'The doctor sees this before they answer. It is the only thing they are told about you.':
      'जवाब देने से पहले डॉक्टर इसे देखते हैं। आपके बारे में उन्हें बस यही बताया जाता है।',
  'Book Anonymously': 'गुमनाम रूप से बुक करें',
  'Find a Doctor Anonymously': 'गुमनाम रूप से डॉक्टर खोजें',
  'Anonymous consultations are voice calls, so the doctor never sees your face.':
      'गुमनाम कंसल्टेशन वॉइस कॉल पर होते हैं, इसलिए डॉक्टर आपका चेहरा कभी नहीं देखते।',
  'Enter Your Code Name': 'अपना कोड नाम डालें',
  'This name will be visible to the doctor instead of your real identity':
      'आपकी असली पहचान की जगह डॉक्टर को यही नाम दिखेगा',
  'Private consultation': 'प्राइवेट कंसल्टेशन',
  'Enter a code name to consult under.': 'परामर्श के लिए एक कोड नाम डालें।',
  'Use at least {count} characters.': 'कम से कम {count} अक्षर लिखें।',
  'Keep it under {count} characters.': '{count} अक्षरों से कम रखें।',
  'Letters, numbers, spaces and hyphens only.':
      'सिर्फ़ अक्षर, अंक, स्पेस और हाइफ़न।',
  'Tell the doctor what you would like to discuss.':
      'डॉक्टर को बताएँ कि आप किस बारे में बात करना चाहते हैं।',
  'A little more detail helps the doctor prepare.':
      'थोड़ी और जानकारी से डॉक्टर बेहतर तैयारी कर पाएँगे।',

  // --- Scheduling --------------------------------------------------------------
  'Schedule Consultation': 'कंसल्टेशन शेड्यूल करें',
  'This doctor has no slots open right now.':
      'इस डॉक्टर के पास अभी कोई स्लॉट खाली नहीं है।',
  'SELECT DATE': 'तारीख चुनें',
  'AVAILABLE TIME SLOTS': 'उपलब्ध समय स्लॉट',
  'CONSULTATION TYPE': 'कंसल्टेशन का प्रकार',
  'Pick a time slot to continue': 'आगे बढ़ने के लिए समय स्लॉट चुनें',
  'Confirm Booking': 'बुकिंग कन्फ़र्म करें',
  'Appointment': 'अपॉइंटमेंट',
  'Consultation Fee': 'कंसल्टेशन फ़ीस',
  'TODAY': 'आज',
  'Morning Slots': 'सुबह के स्लॉट',
  'Afternoon Slots': 'दोपहर के स्लॉट',
  'Evening Slots': 'शाम के स्लॉट',
  'Today, {time}': 'आज, {time}',
  '{date} at {time}': '{date}, {time} बजे',
  '{count} minutes': '{count} मिनट',
  '1 hour': '1 घंटा',
  '{count} hours': '{count} घंटे',
  '{hours} {minutes} minutes': '{hours} {minutes} मिनट',
};
