# Teleconsult on the App Store

Everything needed to build the iOS app on a Mac and publish it on the App Store
for the first time. The repository is already configured. What remains is
account setup in Apple's portals, one Xcode step to pick the signing team, and
filling in App Store Connect.

| | |
|---|---|
| App name on the home screen | **Teleconsult** |
| Bundle ID | `consult.nesliferesearch.ios` (iOS only; Android stays `consult.nesliferesearch.com`. Cannot change after the first upload) |
| Minimum iOS | 15.0 |
| Devices | iPhone only |
| Version | taken from `version:` in `pubspec.yaml` (`1.0.18+18` → version 1.0.18, build 18) |
| Seller | Neslife Research Private Limited |

---

## 1. What is already set up in this repo

| File | What it does |
|---|---|
| `ios/Runner/Info.plist` | Camera, microphone and photo-library purpose strings; background modes `audio` (keeps a call's audio alive with the screen locked) and `remote-notification`; `ITSAppUsesNonExemptEncryption = NO`; UPI app schemes for Razorpay's checkout |
| `ios/Runner/Runner.entitlements` | Push Notifications (`aps-environment`) and Time Sensitive Notifications |
| `ios/Runner/PrivacyInfo.xcprivacy` | Apple's required privacy manifest: no tracking, the data the app collects, and the reasons it reads UserDefaults and file timestamps |
| `ios/Runner/AppDelegate.swift` | Hands notification callbacks to the Firebase and local-notification plugins |
| `ios/Runner/Assets.xcassets/AppIcon.appiconset` | All icons without an alpha channel. App Store Connect rejects a 1024 px icon that has one |
| `ios/ExportOptions.plist` | App Store export settings for `flutter build ipa` |
| `tool/ios_release.sh` | Builds the IPA and optionally uploads it |
| `lib/core/push/push_service.dart` | Waits for the APNs token before asking for the FCM token; the background handler initialises Firebase with explicit options (iOS has no `GoogleService-Info.plist`) |

Plugins are pulled with **Swift Package Manager**, so you do not need CocoaPods,
a `Podfile` or `pod install`.

### Push notifications (FCM) on iOS

Push still goes through Firebase Cloud Messaging. For iPhones, FCM delivers it
through Apple's push service (APNs). That only works after the APNs key is
uploaded to Firebase (step 2.4).

| Push | Android | iPhone |
|---|---|---|
| Incoming consultation (doctor) | Full-screen ringing call, even when the app is closed | Time-sensitive notification with sound, which breaks through Focus mode. Tapping it opens the app, and the in-app ring has Accept/Decline |
| Call ended / missed | Ringing screen taken down | The notification is replaced by a silent "Consultation request ended" |
| Appointment reminders, registration decisions | Notification | Notification (unchanged) |
| "New version on Google Play" | Notification | Not sent. iPhones update through the App Store |

The iPhone call behaviour needs the **API change in `consultation_api`**
(`src/push/push.service.ts`) to be deployed (`bash scripts/deploy.sh`). Before
that deploy, iPhones get call pushes as silent pushes, and iOS drops those for
closed apps.

A full-screen ringing call on a locked iPhone (like WhatsApp) needs Apple's
PushKit + CallKit. That requires a VoIP push sent directly to APNs from the
server, plus native code. It is not built yet; see section 9.

---

## 2. One-time Apple setup

### 2.1 Apple Developer Program, as an organisation

Enrol at <https://developer.apple.com/programs/enroll/> as an **Organization**:
Neslife Research Private Limited. This is not optional for this app. Under
guideline 5.1.1(ix), an app handling health data must be submitted by the legal
entity that provides the service. An individual account will be rejected.

- You need a **D-U-N-S number** for the company (free; Apple's lookup tool
  will request one if the company has none, which takes about 5 working days).
- The enrolling person must have legal authority to bind the company. Use a
  company email domain (`@nesliferesearch.com`).
- The fee is US$99 a year, charged in INR.

### 2.2 Agreements

App Store Connect → **Business**: accept the **Free Apps** agreement. The app is
free and consultation fees go through Razorpay, so no Paid Apps agreement, tax
forms or bank account are needed.

### 2.3 Register the App ID

developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers** → +
→ App IDs → App:

- Description: `Teleconsult`
- Bundle ID (Explicit): `consult.nesliferesearch.ios`
- Capabilities: tick **Push Notifications** and **Time Sensitive Notifications**

With automatic signing, Xcode creates the certificates and provisioning
profiles itself.

### 2.4 APNs key → Firebase (required for any push to reach an iPhone)

1. developer.apple.com → **Keys** → + → name it `Teleconsult APNs`, tick
   **Apple Push Notifications service (APNs)** → Continue → Register.
2. **Download the `.p8` now.** Apple only lets you download it once. Note the
   **Key ID**. Your **Team ID** is at the top right of the developer portal.
3. Firebase console → project `online-consultation-37554` → ⚙ Project settings →
   **Cloud Messaging** → Apple app configuration → the iOS app
   `consult.nesliferesearch.ios` → **APNs Authentication Key** → Upload the
   `.p8` with its Key ID and Team ID.
4. Same settings page, **General** tab → the iOS app `consult.nesliferesearch.ios`:
   add the Team ID, and later the App Store ID. Its App ID is
   `1:505105017093:ios:8441b8a7eb9347f3482f6c`, the `ios` entry in
   `lib/firebase_options.dart`. The older iOS app registered for
   `consult.nesliferesearch.com` (`…:ios:09c529cb1a44be94482f6c`) is unused and
   can be deleted.

One key covers both development and production. Store the `.p8` with the
Android upload keystore backups.

### 2.5 App Store Connect API key (for uploading from the command line)

App Store Connect → Users and Access → **Integrations** → App Store Connect API →
Team Keys → + → name `CI upload`, access **App Manager** → download
`AuthKey_<KEYID>.p8` (again, only once). Note the **Key ID** and the **Issuer
ID** shown above the list.

On the Mac that uploads:

```bash
mkdir -p ~/.appstoreconnect/private_keys
mv ~/Downloads/AuthKey_<KEYID>.p8 ~/.appstoreconnect/private_keys/
```

Skip this if you upload with Xcode or Transporter instead.

---

## 3. Mac setup

1. **Xcode**: the current release from the Mac App Store. App Store Connect
   only accepts builds made with a recent SDK (the iOS 26 SDK or later in
   2026), so an old Xcode will build an IPA that fails upload. Then:
   ```bash
   sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   ```
   In Xcode → Settings → Accounts, sign in with an Apple ID that is a member of
   the Neslife Research team.
2. **Flutter 3.44.0 stable**, the same version as the Windows machine
   (`flutter --version` on both). `flutter doctor` should show Xcode with no
   errors. CocoaPods warnings can be ignored.
3. Clone and fetch packages:
   ```bash
   git clone <repo> && cd consultation_app
   flutter pub get
   ```

### 3.1 Pick the signing team (once, then commit it)

```bash
open ios/Runner.xcworkspace
```

Runner target → **Signing & Capabilities**:

- Tick *Automatically manage signing*. Team: **Neslife Research Private
  Limited**.
- The capability list should already show **Push Notifications**, **Time
  Sensitive Notifications** and **Background Modes** (Audio, Remote
  notifications), because they come from the entitlements file and
  Info.plist. If any is missing, add it with **+ Capability**.

This writes `DEVELOPMENT_TEAM` into `ios/Runner.xcodeproj/project.pbxproj`.
Commit that change so every other Mac builds without this step.

### 3.2 Run it on a real iPhone first

Push, camera and calls do not work on the simulator. Plug in an iPhone (Developer
Mode on: Settings → Privacy & Security → Developer Mode) and:

```bash
flutter run --release
```

Check before uploading:

- [ ] OTP login; the code appears above the keyboard when the SMS arrives
- [ ] Notification permission prompt appears after login
- [ ] Patient: book and pay with Razorpay (UPI apps appear if installed)
- [ ] Video and audio call both ways with an Android phone; lock the iPhone
      mid-call and confirm the audio continues
- [ ] Doctor on the iPhone, app swiped away: a patient call shows the
      notification with sound, and tapping it shows the incoming call (needs
      the API deploy and the APNs key)
- [ ] Patient cancels while ringing → notification changes to "ended"
- [ ] Appointment reminder arrives with the app closed
- [ ] Profile photo from camera and from photos; medical report upload (PDF and
      image)
- [ ] Profile → Delete Account works

---

## 4. Versioning

`version:` in `pubspec.yaml` drives both stores. For iOS:

- `1.0.18` is the App Store **version**. A new version needs a new number once a
  build of the old one has been released.
- `+18` is the **build**. It must be higher than any build already uploaded for
  that version. Bumping it for every Android upload, as you already do, also
  satisfies Apple.

Bump before each upload, as you do for Play.

---

## 5. Build and upload

```bash
# Build only → build/ios/ipa/*.ipa
bash tool/ios_release.sh

# Build and upload
ASC_KEY_ID=<KEYID> ASC_ISSUER_ID=<ISSUER-UUID> bash tool/ios_release.sh
```

The script runs:

```bash
flutter pub get
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
xcrun altool --upload-app --type ios --file build/ios/ipa/<name>.ipa \
  --apiKey <KEYID> --apiIssuer <ISSUER-UUID>
```

**Other ways to upload the same IPA:**

- **Transporter** (free on the Mac App Store): sign in, drag the `.ipa` in,
  Deliver.
- **Xcode**: `open build/ios/archive/Runner.xcarchive` → Organizer →
  Distribute App → App Store Connect → Upload.

After uploading, the build takes 5–30 minutes to process. Apple emails if it is
rejected at this stage, usually over a missing purpose string or an icon
problem. All known causes are already handled.

---

## 6. Create the app in App Store Connect

<https://appstoreconnect.apple.com> → Apps → + → **New App**

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | **Teleconsult by Neslife** — App Store names are unique, and plain "Teleconsult" is likely taken. Max 30 characters. The home-screen name stays "Teleconsult" |
| Primary language | English (U.S.) |
| Bundle ID | `consult.nesliferesearch.ios` (appears once 2.3 is done) |
| SKU | `teleconsult-ios` (internal; never shown) |
| User access | Full access |

### 6.1 App Information

| Field | Value |
|---|---|
| Subtitle | `Consult a doctor online` (max 30) |
| Category | Primary **Medical**, secondary **Health & Fitness** |
| Content rights | "Does not contain, show or access third-party content" |
| Age rating | See 6.4 |
| Privacy Policy URL | A public page. The app's in-app policy points to `https://nesliferesearch.com/privacy-policy`, but that page does not cover health data. **Publish the app's own Privacy Policy and Data Protection Notice** (the text in `lib/features/legal/domain/entities/legal_document.dart`) at a URL such as `https://consult.nesliferesearch.com/privacy`, and use that. Apple checks that the policy covers what the app collects |

### 6.2 Pricing and Availability

- Price: **Free**
- Availability: **India only**. The doctors are registered under NMC and the
  service follows Indian telemedicine rules. Selling elsewhere would also bring
  EU obligations (DSA trader status, medical-device declarations).

### 6.3 App Privacy

App Store Connect → App Privacy → Get Started. Answers must match
`ios/Runner/PrivacyInfo.xcprivacy`.

- **Do you or your third-party partners collect data from this app?** Yes
- For every type below: **Linked to the user: Yes**, **Used for tracking: No**,
  purpose **App Functionality** only

| Category | Data type | What it is in this app |
|---|---|---|
| Contact Info | Name | Patient and doctor names |
| Contact Info | Email Address | Account email |
| Contact Info | Phone Number | OTP login |
| Health & Fitness | Health | Concerns, medical reports, consultation records |
| User Content | Photos or Videos | Profile photo, report and certificate photos, video call recordings |
| User Content | Audio Data | Call recordings |
| User Content | Other User Content | Concerns and notes entered for a consultation |
| Identifiers | User ID | Account ID |
| Identifiers | Device ID | Push notification token |
| Purchases | Purchase History | Consultation payments |
| Other Data | Other Data Types | Date of birth (18+ check), gender |

**Payment Info: do not declare it.** Card and UPI details are entered into
Razorpay's checkout and never reach Neslife's servers. Apple's rule is that
payment details entered into a payment service the developer cannot access are
not collected.

**Tracking: No.** There are no ads, no analytics SDKs and no data sharing with
data brokers.

### 6.4 Age Rating

Answer the questionnaire honestly. The relevant answers:

| Question | Answer |
|---|---|
| Medical or Treatment Information | **Frequent** |
| Health or Wellness Topics | Yes |
| Messaging and Chat / user-to-user communication | Yes (doctor–patient calls) |
| Unrestricted web access, gambling, violence, sexual content, etc. | No / None |
| Parental controls, age assurance | Age assurance: the app collects a date of birth and refuses under-18s |

If the computed rating is below 18+, use **Override to higher rating → 18+**.
The app refuses users under 18, so a lower store rating would be misleading.

### 6.5 Version page (1.0)

**Screenshots:** iPhone 6.9" display, 1320 × 2868 (or 1290 × 2796), PNG or
JPEG, **no alpha channel**, 3–10 images. Apple scales these down for smaller
iPhones. No iPad screenshots are needed because the app is iPhone-only. The
Android screenshots in `store_assets/` are the wrong size and show Android, so
take new ones:

```bash
open -a Simulator           # File → Open Simulator → iPhone 17 Pro Max
flutter run -d "iPhone 17 Pro Max"
xcrun simctl io booted screenshot ~/Desktop/shot-1.png
node tool/png_strip_alpha.js ~/Desktop/shot-*.png
```

Suggested set: home and specialities, doctor list, doctor profile and booking,
a video consultation, medical reports, appointments.

**Promotional text** (max 170, editable without review):

> Talk to a registered doctor by video or audio from home. Book in minutes, pay securely, and keep your reports and receipts in one place.

**Description** (max 4000):

> Teleconsult connects you with registered doctors for online video and audio consultations — without the waiting room.
>
> CONSULT FROM ANYWHERE
> • Choose a speciality and see available doctors with their registration details
> • Start a video or audio consultation, or book one for later
> • Get reminders before your consultation starts
>
> YOUR HEALTH RECORDS, TOGETHER
> • Upload medical reports and photos for your doctor to review
> • Keep your consultation history and receipts in one place
>
> SAFE AND PRIVATE
> • Sign in with your mobile number — no passwords
> • Payments are processed securely by Razorpay
> • Your data is used only to provide your care, and you can delete your account at any time from the app
>
> FOR DOCTORS
> • Register with your medical registration number and certificates
> • Go online to receive consultations and manage your schedule
>
> Teleconsult is for adults (18+). It is not for emergencies — in a medical emergency, call 112 or go to the nearest hospital.
>
> Teleconsult is provided by Neslife Research Private Limited, Mumbai.

**Keywords** (max 100; do not repeat words from the name):

```
doctor,telemedicine,online doctor,video consultation,physician,health,medical,clinic,specialist
```

| Field | Value |
|---|---|
| Support URL | A page with the support email `admin@nesliferesearch.com`, for example `https://nesliferesearch.com/contact`. Email only; no phone number |
| Marketing URL | optional: `https://consult.nesliferesearch.com` |
| Copyright | `2026 Neslife Research Private Limited` |
| Build | pick the uploaded build (after it finishes processing) |

### 6.6 App Review Information

- **Sign-in required: Yes.** Use the same review logins given to Google Play.
  They are in `OTP_REVIEW_ACCOUNTS` in the auth server's `.env`: one patient
  and one doctor phone number, each with a fixed OTP. Enter the patient as the
  username and its OTP as the password, and put the doctor login in the notes.
- **Contact:** a real person at Neslife, with phone and email (Apple only; this
  is not shown publicly).
- **Notes** (paste and adjust):

> Teleconsult is a telemedicine service by Neslife Research Private Limited (India). Patients consult registered medical practitioners by video or audio call.
>
> LOGIN: Phone number + OTP. The demo accounts above accept the fixed OTP shown; no SMS is sent to them.
> • Patient: <patient number> / OTP <code>
> • Doctor: <doctor number> / OTP <code>
>
> TO TEST A CALL: sign in as the doctor on one device and switch to Online; sign in as the patient on another and start a consultation. A demo video of the full flow: <link>.
>
> PAYMENTS: Consultations are real-time one-to-one services between a patient and a doctor, paid through Razorpay under guideline 3.1.3(d). Nothing digital is unlocked by payment.
>
> MEDICAL: Doctors register with their National Medical Commission registration number and certificates, which our team reviews before a doctor can take consultations. The service follows India's Telemedicine Practice Guidelines (2020). The app states it is not for emergencies and is for adults (18+).
>
> BACKGROUND AUDIO: used only to keep a live consultation's audio running when the screen locks.
>
> ACCOUNT DELETION: Profile → Delete Account.

Attach the demo video (screen recording of booking → call → feedback). It is the
single most effective way to avoid a "could not test" rejection. Reviewers
often cannot get a second device online at the same moment.

### 6.7 Version Release

Choose **Manually release this version**, so it goes live when the API deploy
and doctor coverage are ready.

---

## 7. TestFlight first

Every uploaded build appears in **TestFlight**. Add your team as **Internal
Testers** (up to 100 App Store Connect users; no review needed) and run the
section 3.2 checklist on their iPhones. External testers (by email or public
link) need a short beta review the first time.

---

## 8. Submit

Version page → **Add for Review** → **Submit to App Review**. A first review
usually takes 1–3 days. Answer any message from Apple in App Store Connect's
**App Review** section; replying there keeps the same submission.

**Common rejection reasons for this kind of app, and where they stand:**

| Guideline | Risk | Status |
|---|---|---|
| 5.1.1(ix) | Health app from an individual account | Enrol as the company (2.1) |
| 5.1.1(v) | Every account created in the app must be deletable in the app | Patients: done. **Doctors: no in-app deletion found.** Doctors register in the app, so they need a Delete Account entry too (it can start the same server-side erasure the admin console uses) |
| 2.1 | Reviewer could not complete a call | Demo video plus clear notes (6.6) |
| 1.4.1 | Medical credibility | NMC registration review explained in the notes |
| 3.1.1 | "Should use In-App Purchase" | Cite 3.1.3(d), person-to-person services |
| 5.1.1(i) | Privacy policy does not cover the data collected | Publish the app's own policy (6.1) |
| 2.5.4 | Background audio misuse | Only during calls; explained in the notes |
| 2.3.10 | Mentions of Android or Google Play in the app | None found in the UI |

---

## 9. Differences from Android

These are features the iPhone build does not have:

- **Doctor ringing**: notification plus in-app ring, not a full-screen call
  over the lock screen. Adding that needs PushKit VoIP pushes sent from the
  server straight to APNs (a separate `.p8`-signed HTTP/2 client), a
  `PKPushRegistry` in `AppDelegate.swift`, and `flutter_callkit_incoming`'s iOS
  CallKit path. Apple also terminates an app that receives a VoIP push and does
  not show a call, so it needs careful on-device testing.
- **Call recording**: Android only (`CallRecorder` returns early elsewhere).
  Calls with an Android participant are still recorded on that side.
- **In-app update prompt**: Android only. iPhones update through the App Store.
- **Video in the background**: iOS turns off the camera when the app leaves the
  foreground. Audio continues.
