/// Hindi strings for this area of the app, keyed by the English text exactly
/// as it is passed to `tr()`. Keep placeholders like `{name}` unchanged.
///
/// Covers the shared widgets (core/widgets), dates, the app-update prompt,
/// home, notifications, onboarding, startup and the legal/support screens.
const Map<String, String> hiCoreHome = {
  // Shared widgets
  'Retry': 'फिर कोशिश करें',
  'Try again': 'फिर कोशिश करें',
  'Cancel': 'रद्द करें',
  'Done': 'हो गया',
  'Clear search': 'सर्च साफ़ करें',
  'Version {version} ({build})': 'वर्शन {version} ({build})',
  'Appearance': 'थीम',
  'System default follows your phone’s dark mode setting.':
      'सिस्टम डिफ़ॉल्ट आपके फ़ोन की डार्क मोड सेटिंग के हिसाब से चलता है।',
  'System default': 'सिस्टम डिफ़ॉल्ट',
  'Light': 'लाइट',
  'Dark': 'डार्क',
  'Language': 'भाषा',
  'Choose the language the app speaks.': 'ऐप की भाषा चुनें।',
  'Default': 'डिफ़ॉल्ट',
  'Could not open it': 'यह खुल नहीं सका',
  'Cannot preview this file': 'इस फ़ाइल को देखा नहीं जा सकता',
  'It was filed as {type}, which the app cannot display. The reviewer can still open it.':
      'यह {type} के रूप में जमा हुई है, जिसे ऐप नहीं दिखा सकता। जाँच करने वाले इसे फिर भी खोल सकते हैं।',
  'Close the app?': 'ऐप बंद करें?',
  'You can come back any time. Nothing is lost.':
      'आप कभी भी वापस आ सकते हैं। कुछ भी नहीं खोएगा।',
  'Close': 'बंद करें',
  'Stay': 'रुकें',
  'No internet connection': 'इंटरनेट कनेक्शन नहीं है',
  'We could not reach the server. Your device may be connected to a network that has no internet access.':
      'हम सर्वर से नहीं जुड़ पाए। हो सकता है आपका फ़ोन ऐसे नेटवर्क से जुड़ा हो जिसमें इंटरनेट नहीं है।',
  'This will clear on its own once you are back online.':
      'इंटरनेट वापस आते ही यह अपने आप हट जाएगा।',
  '{name} profile photo': '{name} की प्रोफ़ाइल फ़ोटो',
  'Your profile': 'आपकी प्रोफ़ाइल',
  'Change profile photo': 'प्रोफ़ाइल फ़ोटो बदलें',
  // Errors
  'No connection. Check your network and try again.':
      'कनेक्शन नहीं है। अपना नेटवर्क जाँचें और फिर कोशिश करें।',
  'Something went wrong. Please try again.':
      'कुछ गड़बड़ हो गई। कृपया फिर कोशिश करें।',
  // Dates
  'Today': 'आज',
  'Tomorrow': 'कल',
  'Yesterday': 'बीता कल',
  'Just now': 'अभी-अभी',
  '{count} min ago': '{count} मिनट पहले',
  '{count} hr ago': '{count} घंटे पहले',
  '{count} days ago': '{count} दिन पहले',
  'Jan': 'जन॰',
  'Feb': 'फ़र॰',
  'Mar': 'मार्च',
  'Apr': 'अप्रैल',
  'May': 'मई',
  'Jun': 'जून',
  'Jul': 'जुल॰',
  'Aug': 'अग॰',
  'Sep': 'सित॰',
  'Oct': 'अक्टू॰',
  'Nov': 'नव॰',
  'Dec': 'दिस॰',
  'Mon': 'सोम',
  'Tue': 'मंगल',
  'Wed': 'बुध',
  'Thu': 'गुरु',
  'Fri': 'शुक्र',
  'Sat': 'शनि',
  'Sun': 'रवि',
  // App update
  'Faster and smoother': 'पहले से तेज़ और स्मूद',
  'What’s new': 'क्या नया है',
  'Version {version}': 'वर्ज़न {version}',
  'Version {version} is available.': 'वर्ज़न {version} उपलब्ध है।',
  'This update is required to keep using the app.':
      'ऐप का उपयोग जारी रखने के लिए यह अपडेट ज़रूरी है।',
  'Latest security fixes': 'नए सुरक्षा सुधार',
  'New improvements': 'नए सुधार',
  'Update now': 'अभी अपडेट करें',
  'Later': 'बाद में',
  'Getting the update ready': 'अपडेट तैयार हो रहा है',
  'Updating the app': 'ऐप अपडेट हो रहा है',
  'Update ready': 'अपडेट तैयार है',
  'Update didn’t finish': 'अपडेट पूरा नहीं हुआ',
  'Important update': 'ज़रूरी अपडेट',
  'A new version is ready': 'नया वर्शन तैयार है',
  'You can keep using the app. We’ll restart it when it’s done.':
      'आप ऐप इस्तेमाल करते रहें। पूरा होने पर हम इसे फिर से चालू कर देंगे।',
  'Restarting the app…': 'ऐप फिर से चालू हो रहा है…',
  'Check your connection and try again.':
      'अपना कनेक्शन जाँचें और फिर कोशिश करें।',
  'Please update to keep consulting without interruptions.':
      'बिना रुकावट परामर्श जारी रखने के लिए कृपया अपडेट करें।',
  'Update now for the best consultation experience.':
      'बेहतरीन परामर्श अनुभव के लिए अभी अपडेट करें।',
  'A newer version of the app is available.': 'ऐप का नया वर्शन उपलब्ध है।',
  'Update': 'अपडेट',
  // Navigation
  'Home': 'होम',
  'Appointments': 'अपॉइंटमेंट',
  'Patients': 'मरीज़',
  'Earnings': 'कमाई',
  'Profile': 'प्रोफ़ाइल',
  // Patient home
  'Stop looking?': 'खोज बंद करें?',
  'We will withdraw your request. You can ask for a doctor again whenever you like.':
      'हम आपका अनुरोध वापस ले लेंगे। आप जब चाहें फिर से डॉक्टर के लिए कह सकते हैं।',
  'Stop looking': 'खोज बंद करें',
  'Keep waiting': 'इंतज़ार करें',
  'Request withdrawn.': 'अनुरोध वापस ले लिया गया।',
  'Consult Now': 'अभी परामर्श लें',
  'Connect instantly with a doctor': 'तुरंत डॉक्टर से जुड़ें',
  'Anonymous Consult': 'गुमनाम परामर्श',
  'Talk to a doctor privately': 'डॉक्टर से निजी तौर पर बात करें',
  'You agree to have an anonymous consultation. The doctor will not know who you are, and medicines will not be recommended or prescribed in an anonymous consultation.':
      'आप गुमनाम परामर्श के लिए सहमत हैं। डॉक्टर को आपकी पहचान नहीं पता होगी, और गुमनाम परामर्श में दवाइयाँ सुझाई या लिखी नहीं जाएँगी।',
  'I agree': 'मैं सहमत हूँ',
  'Please read and agree before you continue.':
      'आगे बढ़ने से पहले कृपया पढ़ें और सहमति दें।',
  'Your identity stays hidden': 'आपकी पहचान छिपी रहती है',
  'The doctor sees only your code name, never your name, number or photo.':
      'डॉक्टर केवल आपका कोड नाम देखते हैं, आपका नाम, नंबर या फ़ोटो कभी नहीं।',
  'No medicines will be prescribed': 'कोई दवा नहीं लिखी जाएगी',
  'An anonymous consultation is for advice and guidance only. Medicines will not be recommended or prescribed.':
      'गुमनाम परामर्श केवल सलाह और मार्गदर्शन के लिए है। दवाइयाँ सुझाई या लिखी नहीं जाएँगी।',
  'Your concern is what the doctor reads': 'डॉक्टर आपकी समस्या पढ़ते हैं',
  'Describe it in your own words so the doctor can prepare before they answer.':
      'इसे अपने शब्दों में लिखें ताकि डॉक्टर जवाब देने से पहले तैयारी कर सकें।',
  'I agree, continue': 'मैं सहमत हूँ, आगे बढ़ें',
  // Call recordings: profile section, recordings chat and player.
  'Call recordings': 'कॉल रिकॉर्डिंग',
  '1 recording · {date}': '1 रिकॉर्डिंग · {date}',
  '{n} recordings · {date}': '{n} रिकॉर्डिंग · {date}',
  'Recordings of your audio and video consultations will appear here.':
      'आपके ऑडियो और वीडियो परामर्श की रिकॉर्डिंग यहाँ दिखाई देंगी।',
  'Consultation recordings': 'परामर्श रिकॉर्डिंग',
  'Your consultation recordings with this doctor or patient appear here. They are private to the two of you.':
      'इस डॉक्टर या मरीज़ के साथ आपके परामर्श की रिकॉर्डिंग यहाँ दिखाई देती हैं। ये केवल आप दोनों के लिए निजी हैं।',
  'Video consultation recording': 'वीडियो परामर्श रिकॉर्डिंग',
  'Audio consultation recording': 'ऑडियो परामर्श रिकॉर्डिंग',
  'No recordings yet.': 'अभी कोई रिकॉर्डिंग नहीं है।',
  'Messaging is not available. Only call recordings are shared here.':
      'मैसेज भेजने की सुविधा उपलब्ध नहीं है। यहाँ केवल कॉल रिकॉर्डिंग साझा की जाती हैं।',
  'This recording could not be played. Check your connection and try again.':
      'यह रिकॉर्डिंग चल नहीं सकी। अपना कनेक्शन जाँचें और फिर से कोशिश करें।',
  'Could not load your recordings. Pull down to try again.':
      'आपकी रिकॉर्डिंग लोड नहीं हो सकीं। फिर से कोशिश करने के लिए नीचे खींचें।',
  'Video call recording': 'वीडियो कॉल रिकॉर्डिंग',
  'Audio call recording': 'ऑडियो कॉल रिकॉर्डिंग',
  'Video call': 'वीडियो कॉल',
  'Audio call': 'ऑडियो कॉल',
  '1 recording': '1 रिकॉर्डिंग',
  '{n} recordings': '{n} रिकॉर्डिंग',
  'Tap to retry': 'फिर से कोशिश करने के लिए टैप करें',
  'Chat & recordings': 'चैट और रिकॉर्डिंग',
  'Loading…': 'लोड हो रहा है…',
  'No recordings yet': 'अभी कोई रिकॉर्डिंग नहीं',
  'Recorded audio and video consultations, with their transcripts.':
      'रिकॉर्ड किए गए ऑडियो और वीडियो परामर्श, उनकी ट्रांसक्रिप्ट के साथ।',
  '1 consultation recorded': '1 परामर्श रिकॉर्ड हुआ',
  '{n} consultations recorded': '{n} परामर्श रिकॉर्ड हुए',
  'Open chat': 'चैट खोलें',
  'Recordings': 'रिकॉर्डिंग',
  'Minutes': 'मिनट',
  'Transcripts': 'ट्रांसक्रिप्ट',
  'Private to you and the other person in the call':
      'केवल आपके और कॉल में शामिल दूसरे व्यक्ति के लिए निजी',
  'No recordings of this kind yet.': 'इस प्रकार की कोई रिकॉर्डिंग अभी नहीं है।',
  'All': 'सभी',
  'Video': 'वीडियो',
  'Audio': 'ऑडियो',
  'Video consultation': 'वीडियो परामर्श',
  'Audio consultation': 'ऑडियो परामर्श',
  'Transcript available': 'ट्रांसक्रिप्ट उपलब्ध है',
  'Auto-generated · may contain errors':
      'स्वचालित रूप से बनाई गई · इसमें गलतियाँ हो सकती हैं',
  'Transcript': 'ट्रांसक्रिप्ट',
  'Show full transcript': 'पूरी ट्रांसक्रिप्ट देखें',
  'Show less': 'कम दिखाएँ',
  'Transcript is being prepared…': 'ट्रांसक्रिप्ट तैयार की जा रही है…',
  'No transcript available': 'कोई ट्रांसक्रिप्ट उपलब्ध नहीं',
  'Back 10 seconds': '10 सेकंड पीछे',
  'Forward 10 seconds': '10 सेकंड आगे',
  'Pause': 'रोकें',
  'Play': 'चलाएँ',
  // Consent popup, both consultations.
  'Terms and consent': 'नियम और सहमति',
  'Please read all the points below carefully.':
      'कृपया नीचे दिए गए सभी बिंदु ध्यान से पढ़ें।',
  'Scroll to read all terms': 'सभी नियम पढ़ने के लिए स्क्रॉल करें',
  'I have read and understood all the points above, and I give my consent to the video consultation.':
      'मैंने ऊपर दिए गए सभी बिंदु पढ़ और समझ लिए हैं, और मैं वीडियो परामर्श के लिए अपनी सहमति देता/देती हूँ।',
  'I have read and understood all the points above, and I give my consent to the anonymous consultation.':
      'मैंने ऊपर दिए गए सभी बिंदु पढ़ और समझ लिए हैं, और मैं गुमनाम परामर्श के लिए अपनी सहमति देता/देती हूँ।',
  // Video consultation terms.
  'I consent to a video consultation with a registered medical practitioner through this app.':
      'मैं इस ऐप के माध्यम से एक पंजीकृत चिकित्सक के साथ वीडियो परामर्श के लिए सहमति देता/देती हूँ।',
  'I understand that the session may be recorded or shared only with my explicit consent.':
      'मैं समझता/समझती हूँ कि सत्र केवल मेरी स्पष्ट सहमति से ही रिकॉर्ड या साझा किया जा सकता है।',
  'I give that consent: my audio or video call will be recorded on my own phone, and a compressed copy will be stored securely so that my doctor and I can watch or listen to it later in the app.':
      'मैं यह सहमति देता/देती हूँ: मेरी ऑडियो या वीडियो कॉल मेरे अपने फ़ोन पर रिकॉर्ड होगी, और उसकी एक कंप्रेस की हुई कॉपी सुरक्षित रूप से संग्रहीत की जाएगी, ताकि मेरे डॉक्टर और मैं बाद में ऐप में उसे देख या सुन सकें।',
  'I understand that my video and personal information will be handled confidentially and in accordance with applicable privacy guidelines.':
      'मैं समझता/समझती हूँ कि मेरा वीडियो और व्यक्तिगत जानकारी गोपनीय रूप से और लागू गोपनीयता दिशानिर्देशों के अनुसार संभाली जाएगी।',
  'I will give accurate and complete information about my health, current medicines and allergies, so the doctor can advise me safely.':
      'मैं अपने स्वास्थ्य, वर्तमान दवाओं और एलर्जी के बारे में सही और पूरी जानकारी दूँगा/दूँगी, ताकि डॉक्टर मुझे सुरक्षित सलाह दे सकें।',
  'I understand that a video consultation has limits, and the doctor may advise an in-person visit, tests or a specialist if needed.':
      'मैं समझता/समझती हूँ कि वीडियो परामर्श की सीमाएँ हैं, और ज़रूरत पड़ने पर डॉक्टर व्यक्तिगत मुलाक़ात, जाँच या विशेषज्ञ की सलाह दे सकते हैं।',
  'I understand that any prescription is issued at the doctor’s discretion and as permitted by law.':
      'मैं समझता/समझती हूँ कि कोई भी पर्चा डॉक्टर के विवेक पर और क़ानून की अनुमति के अनुसार ही दिया जाता है।',
  'I will join from a private place with a stable internet connection. A poor connection may affect the consultation.':
      'मैं किसी निजी जगह से, स्थिर इंटरनेट कनेक्शन के साथ जुड़ूँगा/जुड़ूँगी। कमज़ोर कनेक्शन परामर्श को प्रभावित कर सकता है।',
  'This service is not for emergencies. In an emergency I will call 112 or go to the nearest hospital.':
      'यह सेवा आपातकाल के लिए नहीं है। आपातकाल में मैं 112 पर कॉल करूँगा/करूँगी या नज़दीकी अस्पताल जाऊँगा/जाऊँगी।',
  // Anonymous consultation terms.
  'I understand that anonymous consultations do not include prescriptions for medicines or drugs.':
      'मैं समझता/समझती हूँ कि गुमनाम परामर्श में दवाओं का पर्चा शामिल नहीं होता।',
  'I understand that anonymous consultations are available only for eligible psychological counselling services.':
      'मैं समझता/समझती हूँ कि गुमनाम परामर्श केवल योग्य मनोवैज्ञानिक परामर्श सेवाओं के लिए उपलब्ध है।',
  'I will use my code name, and I will not share my real name, phone number or other details that identify me during the session.':
      'मैं अपने कोड नाम का उपयोग करूँगा/करूँगी, और सत्र के दौरान अपना असली नाम, फ़ोन नंबर या पहचान बताने वाली कोई जानकारी साझा नहीं करूँगा/करूँगी।',
  'I understand that the doctor will not see my name, phone number or photo.':
      'मैं समझता/समझती हूँ कि डॉक्टर मेरा नाम, फ़ोन नंबर या फ़ोटो नहीं देखेंगे।',
  'I will describe my concern honestly, as it is the only information the doctor has before answering.':
      'मैं अपनी समस्या ईमानदारी से बताऊँगा/बताऊँगी, क्योंकि जवाब देने से पहले डॉक्टर के पास केवल यही जानकारी होती है।',
  'I understand that if my concern needs an examination, tests or medicines, the doctor may advise a regular consultation instead.':
      'मैं समझता/समझती हूँ कि यदि मेरी समस्या के लिए जाँच, टेस्ट या दवाओं की ज़रूरत है, तो डॉक्टर सामान्य परामर्श की सलाह दे सकते हैं।',
  'This service is not for emergencies or crisis situations. If I am at risk of harming myself or others, I will call 112 or Tele-MANAS on 14416.':
      'यह सेवा आपातकाल या संकट की स्थितियों के लिए नहीं है। यदि मुझे ख़ुद को या दूसरों को नुकसान पहुँचाने का ख़तरा हो, तो मैं 112 या टेली-मानस 14416 पर कॉल करूँगा/करूँगी।',
  'Exit': 'बाहर निकलें',
  'Leave {app}?': '{app} से बाहर निकलें?',
  'You will stay signed in, and your appointment reminders will still reach you.':
      'आप साइन इन रहेंगे, और आपके अपॉइंटमेंट रिमाइंडर आपको मिलते रहेंगे।',
  'Stress Management': 'तनाव प्रबंधन',
  'By speciality': 'विशेषज्ञता के अनुसार',
  'See All': 'सभी देखें',
  'Last consultation': 'पिछला परामर्श',
  'History': 'हिस्ट्री',
  'Consult again': 'फिर से परामर्श लें',
  'Doctor': 'डॉक्टर',
  'Last: {date}': 'पिछली बार: {date}',
  'Consult': 'परामर्श लें',
  'Consultation in progress': 'परामर्श चल रहा है',
  'We are looking for a doctor who is free now.':
      'हम ऐसे डॉक्टर को ढूँढ रहे हैं जो अभी खाली हों।',
  'Rejoin': 'फिर से जुड़ें',
  'Good morning': 'सुप्रभात',
  'Good afternoon': 'नमस्ते',
  'Good evening': 'शुभ संध्या',
  'there': 'दोस्त',
  'How can we help you today?': 'आज हम आपकी क्या मदद कर सकते हैं?',
  'Search doctors': 'डॉक्टर खोजें',
  'Search doctors, specialities…': 'डॉक्टर, विशेषज्ञता खोजें…',
  // Specialities
  'Internal Medicine': 'इंटरनल मेडिसिन',
  'Dermatology': 'त्वचा रोग',
  'Paediatrics': 'बाल रोग',
  'Pediatrics': 'बाल रोग',
  'Cardiology': 'हृदय रोग',
  'Neurology': 'न्यूरोलॉजी',
  'Dentistry': 'दंत चिकित्सा',
  'General Physician': 'जनरल फ़िज़िशियन',
  'General': 'जनरल',
  'Dentist': 'दंत चिकित्सक',
  'Cardio': 'हृदय',
  'Cardiologist': 'हृदय रोग विशेषज्ञ',
  'Pediatrician': 'बाल रोग विशेषज्ञ',
  // Appointment status and mode
  'Confirmed': 'कन्फ़र्म',
  'Waiting': 'इंतज़ार में',
  'In Progress': 'चल रहा है',
  'In progress': 'चल रहा है',
  'Finding a doctor': 'डॉक्टर ढूँढ रहे हैं',
  'Ringing': 'घंटी बज रही है',
  'Accepted': 'स्वीकार किया गया',
  'Completed': 'पूरे हुए',
  'Cancelled': 'रद्द',
  'No answer': 'जवाब नहीं मिला',
  'Video Consultation': 'वीडियो परामर्श',
  'Audio Consultation': 'ऑडियो परामर्श',
  // Doctor home
  'Upcoming Appointments': 'आने वाले अपॉइंटमेंट',
  'Nothing booked yet.': 'अभी कोई बुकिंग नहीं है।',
  'Go online and patients can reach you straight away.':
      'ऑनलाइन हों, ताकि मरीज़ आपसे तुरंत जुड़ सकें।',
  '{count} consultation': '{count} परामर्श',
  '{count} consultations': '{count} परामर्श',
  'Upcoming': 'आने वाले',
  'appointment': 'अपॉइंटमेंट',
  'appointments': 'अपॉइंटमेंट',
  'consultation': 'परामर्श',
  'consultations': 'परामर्श',
  'Anonymous booking': 'गुमनाम बुकिंग',
  'Booked appointment': 'बुक किया गया अपॉइंटमेंट',
  'View {name}': '{name} को देखें',
  'Start Call': 'कॉल शुरू करें',
  'Details': 'विवरण',
  'Consults': 'परामर्श',
  'Billed today': 'आज का बिल',
  'Rating': 'रेटिंग',
  'Why they are consulting': 'परामर्श की वजह',
  'Anonymous consultation': 'गुमनाम परामर्श',
  'Instant consultation': 'तुरंत परामर्श',
  'With you': 'आपके साथ',
  'Consultations': 'परामर्श',
  'Billed': 'बिल किया गया',
  'This is your first consultation with them.':
      'उनके साथ यह आपका पहला परामर्श है।',
  'This patient booked anonymously, so their past consultations are not linked to this one.':
      'इस मरीज़ ने गुमनाम रूप से बुक किया है, इसलिए उनके पिछले परामर्श इससे जुड़े नहीं हैं।',
  'You are online. Tap to stop taking consultations.':
      'आप ऑनलाइन हैं। परामर्श लेना बंद करने के लिए टैप करें।',
  'You are offline. Tap to start taking consultations.':
      'आप ऑफ़लाइन हैं। परामर्श लेना शुरू करने के लिए टैप करें।',
  'Online': 'ऑनलाइन',
  'Offline': 'ऑफ़लाइन',
  'Tap to go offline': 'ऑफ़लाइन होने के लिए टैप करें',
  'Tap to go online': 'ऑनलाइन होने के लिए टैप करें',
  'Patients can reach you for an instant consultation':
      'मरीज़ तुरंत परामर्श के लिए आपसे जुड़ सकते हैं',
  'Only booked appointments will reach you':
      'सिर्फ़ बुक किए गए अपॉइंटमेंट ही आप तक पहुँचेंगे',
  // Call ringing setup
  'Calls may not ring when the app is closed':
      'ऐप बंद होने पर कॉल की घंटी शायद न बजे',
  '1 setting to fix on this phone': 'इस फ़ोन पर 1 सेटिंग ठीक करनी है',
  '{count} settings to fix on this phone':
      'इस फ़ोन पर {count} सेटिंग ठीक करनी हैं',
  'Fix': 'ठीक करें',
  'Make sure calls ring': 'पक्का करें कि कॉल की घंटी बजे',
  'When the app is closed, your phone decides whether a patient’s call can ring. These settings let it.':
      'ऐप बंद होने पर आपका फ़ोन तय करता है कि मरीज़ की कॉल की घंटी बजेगी या नहीं। ये सेटिंग इसकी इजाज़त देती हैं।',
  'All set. Calls will ring even with the app closed.':
      'सब तैयार है। ऐप बंद होने पर भी कॉल की घंटी बजेगी।',
  'I’ve allowed it': 'मैंने इजाज़त दे दी',
  'Allow notifications': 'नोटिफ़िकेशन की इजाज़त दें',
  'Show calls on the lock screen': 'लॉक स्क्रीन पर कॉल दिखाएँ',
  'Remove battery restriction': 'बैटरी की पाबंदी हटाएँ',
  'Allow auto-start': 'ऑटो-स्टार्ट की इजाज़त दें',
  'Without them a patient’s call cannot ring at all.':
      'इनके बिना मरीज़ की कॉल की घंटी बिल्कुल नहीं बज सकती।',
  'So a call rings full screen, not as a small notification.':
      'ताकि कॉल छोटे नोटिफ़िकेशन की जगह पूरी स्क्रीन पर बजे।',
  'Choose “Don’t optimise” or “Unrestricted” for Teleconsult, so calls are not held back.':
      'Teleconsult के लिए “ऑप्टिमाइज़ न करें” या “कोई पाबंदी नहीं” चुनें, ताकि कॉल न रुकें।',
  'Your phone stops closed apps from waking up. Turn Teleconsult on in the list that opens, then come back and confirm.':
      'आपका फ़ोन बंद ऐप्स को चालू होने से रोकता है। खुलने वाली लिस्ट में Teleconsult चालू करें, फिर वापस आकर पुष्टि करें।',
  'Allow': 'इजाज़त दें',
  'Open settings': 'सेटिंग खोलें',
  // Notifications
  'Notifications': 'नोटिफ़िकेशन',
  'Notifications, {count} unread': 'नोटिफ़िकेशन, {count} बिना पढ़े',
  'Nothing yet': 'अभी कुछ नहीं',
  'Booking confirmations and appointment reminders will appear here.':
      'बुकिंग की पुष्टि और अपॉइंटमेंट के रिमाइंडर यहाँ दिखेंगे।',
  'new update\nof {total} in your care feed':
      'नया अपडेट\nआपकी केयर फ़ीड के {total} में से',
  'new updates\nof {total} in your care feed':
      'नए अपडेट\nआपकी केयर फ़ीड के {total} में से',
  'You’re all caught up\n{total} in your care feed':
      'आपने सब देख लिया है\nआपकी केयर फ़ीड में {total}',
  'Read all': 'सब पढ़ा हुआ करें',
  'NEW': 'नया',
  'Booking': 'बुकिंग',
  'Reminder': 'रिमाइंडर',
  'Starting': 'शुरू हो रहा है',
  'New appointment booked': 'नया अपॉइंटमेंट बुक हुआ',
  'Consultation booked': 'परामर्श बुक हो गया',
  'Your consultation is starting': 'आपका परामर्श शुरू हो रहा है',
  // Onboarding and startup
  'Care. Anytime. Anywhere.': 'देखभाल। कभी भी। कहीं भी।',
  'Trusted by doctors. Loved by patients.':
      'डॉक्टरों का भरोसा। मरीज़ों की पसंद।',
  'Choose how you want to continue': 'चुनें कि आप कैसे आगे बढ़ना चाहते हैं',
  'Continue as Patient': 'मरीज़ के रूप में आगे बढ़ें',
  'Continue as Doctor': 'डॉक्टर के रूप में आगे बढ़ें',
  'Patient': 'मरीज़',
  'patient': 'मरीज़',
  'doctor': 'डॉक्टर',
  'Could not continue. Please try again.':
      'आगे नहीं बढ़ पाए। कृपया फिर कोशिश करें।',
  'This number is already registered as a {role}. Go back and continue as {role}, or use a different number.':
      'यह नंबर पहले से {role} के रूप में रजिस्टर्ड है। वापस जाकर {role} के रूप में आगे बढ़ें, या कोई दूसरा नंबर इस्तेमाल करें।',
  'Your registration was not finished. Sign in again to start over.':
      'आपका रजिस्ट्रेशन पूरा नहीं हुआ था। नए सिरे से शुरू करने के लिए फिर से साइन इन करें।',
  "We couldn't confirm your account. Check your connection, then continue below.":
      'हम आपके अकाउंट की पुष्टि नहीं कर पाए। अपना कनेक्शन जाँचें, फिर नीचे से आगे बढ़ें।',
  'Your session has ended. Please sign in again.':
      'आपका सेशन खत्म हो गया है। कृपया फिर से साइन इन करें।',
  'Please sign in again to continue.':
      'जारी रखने के लिए कृपया फिर से साइन इन करें।',
  // Legal and support
  'Contact Us': 'हमसे संपर्क करें',
  'Email us': 'हमें ईमेल करें',
  'We reply to email within one working day':
      'हम एक कामकाजी दिन के अंदर ईमेल का जवाब देते हैं',
  'Monday to Saturday, 9:00 AM to 8:00 PM IST':
      'सोमवार से शनिवार, सुबह 9:00 से रात 8:00 बजे तक (IST)',
  'Data protection': 'डेटा सुरक्षा',
  'Grievance Officer': 'शिकायत अधिकारी',
  'For complaints about how your data is handled':
      'आपके डेटा के इस्तेमाल से जुड़ी शिकायतों के लिए',
  'Registered office': 'रजिस्टर्ड ऑफ़िस',
  'In an emergency': 'इमरजेंसी में',
  'Call your local emergency number or go to the nearest hospital. Support cannot help with a medical emergency.':
      'अपने इलाके के इमरजेंसी नंबर पर कॉल करें या नज़दीकी अस्पताल जाएँ। मेडिकल इमरजेंसी में सपोर्ट टीम मदद नहीं कर सकती।',
  'Copied {value}': '{value} कॉपी हो गया',
  'Last updated {date}': 'आखिरी बार अपडेट: {date}',
  'Data Protection Notice': 'डेटा सुरक्षा सूचना',
  'Privacy Policy': 'प्राइवेसी पॉलिसी',
  'Terms & Conditions': 'नियम और शर्तें',
  'Cancellation & Refund Policy': 'कैंसलेशन और रिफ़ंड पॉलिसी',
};
