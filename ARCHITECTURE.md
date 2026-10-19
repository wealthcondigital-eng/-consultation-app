# Architecture

## Layers

Each feature is a vertical slice with three layers. Dependencies point inward
only — `presentation → domain ← data`. Domain imports nothing from the other two.

```
lib/
  main.dart                     # binding + DI + runApp
  app/
    app.dart                    # MaterialApp, installs AppSizingScope
    router/                     # named routes + the single route table
  core/                         # shared across features
    di/                         # service locator + object graph
    responsive/                 # breakpoints and the dimension tokens
    theme/                      # colours, type scale, ThemeData
    widgets/                    # AppButton, ResponsivePage
  features/<feature>/
    domain/                     # entities, repository interfaces, use cases
    data/                       # data sources, repository implementations
    presentation/               # controllers, screens, widgets
```

Adding a screen: entity + repository interface + use case in `domain`,
implementation in `data`, a `ChangeNotifier` controller and the screen in
`presentation`, register in `core/di/injector.dart`, add the route in
`app/router/`.

## Responsive sizing

No widget hard-codes a dimension. Every design value lives in
`core/responsive/app_sizing.dart` and is read via `context.sizing`:

```dart
final sizing = context.sizing;
SizedBox(height: sizing.spacingXl)      // 24 design px, scaled
Text('MediCare', style: sizing.text.brandTitle)
```

Design values are expressed against the Figma frame (402×874) and multiplied by
a scale derived from the running window:

- `w()` / `h()` / `sp()` scale horizontal, vertical and type values.
- Scales are **clamped** (`app_breakpoints.dart`) so a 320pt phone stays legible
  and a tablet does not get oversized controls.
- On screens wider than 480pt the content column is capped and centred by
  `ResponsivePage` rather than stretched.
- System text scaling is applied by Flutter *on top* of `sp()`, so accessibility
  settings keep working.

`ResponsivePage` also makes every screen scroll when it is taller than the
viewport, which is what keeps `Spacer`-based layouts safe on short devices.

New screens should be added to the device matrix in
`test/features/onboarding/presentation/landing_screen_test.dart`, which asserts
no overflow across six screen sizes.

## Sibling projects

This repository is **the Flutter app only**. The backend and the administrator
console are separate projects beside it, because they are separate deployables
with separate stacks and release cycles.

| Project | What | Port |
| --- | --- | --- |
| `consultation_app/` | This — the Flutter app, patients and doctors | — |
| `consultation_api/api/` | NestJS API, Mongoose over MongoDB Atlas | 4100 |
| `consultation_api/server/` | Express API, still owns the phone-OTP flow. Being retired. | 4000 |
| `consultation_admin/` | The administrator console, Next.js | 3100 |

The data model and every API contract are written down in
`../consultation_api/docs/DATA_MODEL.md`.

Two API processes exist only during the migration, both against the same Atlas
database. `api/` owns the review queue and the administrator roster; `server/`
still owns OTP login until that flow is ported, at which point it goes away.
`api/src/database/schemas/user.schema.ts` is deliberately a field-for-field port
of `server/src/models/user.js` so the shared `users` collection has one shape.

**This app holds no database credential.** It reaches MongoDB only through the
API, over a bearer token — anything compiled into a binary is public, so
`AppConfig` carries an endpoint and nothing else.

Supabase and Firebase have been removed. `AppBackend.live` in
`core/di/injector.dart` wires every data source to `ApiClient`; the three
`Supabase*RemoteDataSource` classes were replaced by `Api*RemoteDataSource`
equivalents that document the endpoints they expect in their class comments.
What the Postgres RLS policies and triggers used to guarantee — a doctor writing
only inside their own record, only an administrator moving the review fields —
is now guards on the API. The authority moved; it did not disappear.

## Instant consultations

A patient tapping **Consult Now** and a doctor answering are two views of one
record in the API's `consultations` collection. The app holds it as
`LiveConsultation`, and the flow is polled at both ends:

```
patient                        API                          doctor
  POST /consultations/instant  ──▶ searching
  GET  /consultations/:id  (2s) ──▶ ringing  ──▶ GET /consultations/incoming (3s)
                                                POST /consultations/:id/accept
  ◀── accepted, with channelId ────────────────────▶ accepted, same channelId
  POST /:id/join                                   POST /:id/join
       └── WebRTC over /consultations/:id/signal (both directions) ──┘
  POST /:id/end                                    POST /:id/end
```

Signalling moved off the Express `/call/*` routes and into the consultation.
Those routes took a `sender` string from the app and no token at all, so anyone
who learned a channel name could join a medical call, and — because both sides
sent the doctor's id — each discarded the other's offer as its own echo. Now the
API reads which end of the call you are from the bearer token, and only the two
people in the consultation can reach the channel.

**The media does not go through the server.** It goes phone to phone, which is
why `GET /consultations/ice-servers` exists: STUN lets a phone find its own
public address, and TURN relays the stream when neither side can be reached
directly — the normal case for two phones on mobile data. Without a TURN server
configured, calls connect on wifi and fail on mobile. The app never holds those
credentials; the API mints a short-lived one per user.

The call timer is anchored to the server's `startedAt`, so both phones show the
same duration, and the same poll that carries it is how a hang-up reaches the
other side — a phone that lost signal closes no peer connection.

Three things the record decides that the app must not:

- **`channelId`** — the room, minted per consultation. Both home screens used to
  hard-code `consult-room-1`, so every call shared one room.
- **`peerId`** — who this device is inside it. The signalling store filters an
  offer by comparing senders, and both sides used to send the doctor's id, so
  each discarded the other's SDP as its own echo.
- **`isCaller`** — which side offers. Previously each device asked "has anyone
  offered yet?" and became the caller if not: a race both could win.

The doctor's incoming poll doubles as their presence heartbeat, which is why
`IncomingConsultationController` lives on the home screen rather than on a screen
of its own — a doctor marked online whom nobody is polling stops being offered
calls after ninety seconds.

## Scheduled consultations

A booking is the same record as an instant consultation with two fields set:
`scheduledAt` and `status: 'scheduled'`. There is no second collection and no
second entity, for the same reason there is one `Appointment` for both roles —
the alternative is two mappers, two cards, and two chances to get one of them
wrong.

```
patient                          API                            doctor
  POST /consultations/schedule ──▶ scheduled
                                   ├─▶ GET /doctors/me/dashboard?scope=upcoming
                                   └─▶ GET /*/me/appointments?filter=upcoming
  ... the day arrives ...
  POST /:id/join  ────────────────▶ in_progress ◀──────────── POST /:id/join
```

Nobody is rung, because the appointment **is** the agreement. That is also why
`scheduled` is deliberately **not** in `LIVE_STATUSES`: a doctor with a Thursday
appointment is not busy on Tuesday, and a patient with one is not barred from
asking for a doctor today. `UPCOMING_STATUSES` is the list that includes it, and
the two names exist separately so they cannot be merged by accident.

This did not work at all, and the reason is worth writing down: **nothing was
ever written.** The booking flow ran slot picker → payment → a screen that said
"Appointment scheduled" and navigated home. The slot existed only as a sentence
the patient had read. There was no row on the doctor's dashboard because there
was no row. Three things had to change together:

- **The slot had to become a time.** `ScheduleConsultationScreen` carried
  `appointmentLabel` — `Mon, 18 Aug at 10:30 AM` — and nothing else. A label is
  not something a diary can hold, so `selectedSlotAt` is what travels now and
  the label is only what gets read.
- **Paying had to file it.** `PaymentController.pay` takes `scheduledAt` and
  books inside the same call, so paying and holding the slot either both happen
  or neither does. Paid first, deliberately: the reverse leaves a doctor's diary
  holding an appointment nobody paid for whenever the second step fails, and
  that one is invisible until they turn up for it.
- **Both ends had to read it.** The dashboard ran one query, over
  `LIVE_STATUSES`, and ignored the `?scope=upcoming` the app had been sending
  since it started grouping by date — so even once a row existed, nothing
  selected it. Both appointment lists' `upcoming` filter had the same hole.

Two smaller rules the flow now holds to:

- **A booking opens only as its time comes round.** Fifteen minutes before,
  through to an hour after; the API refuses a join outside that window, and the
  app's buttons follow the same numbers so nothing offers a call that would be
  refused. It carries a `channelId` from the moment it is made, so
  `channelId != null` alone would have put Rejoin on a Tuesday card for a
  Thursday appointment.
- **A slot is booked once.** Two patients tapping the same slot seconds apart
  both saw it free on the strip; the second is told, rather than quietly written
  as a double booking.

## The concern

What the patient typed on the way in travels on the consultation itself, and is
shown to the doctor **before** they answer — on the incoming-call banner, on the
appointment card, on both appointment lists. It was collected on the anonymous
booking form and went nowhere.

That matters most on an anonymous consultation, where it is the only thing the
doctor is told about the person ringing them. A sheet showing an alias, a time
and nothing else asks somebody to accept a call about they know not what, which
is not a decision.

## Anonymous consultations are voice calls

The form offered Audio and Video as two equal segments. A video call hands the
doctor the patient's face, which undoes the alias, the language picker and every
other promise on the screen — in one mis-tap, and not undoably. There is no
control now; `AnonymousBooking.mode` is a getter that answers `audio`, and a
sentence on the screen says why.

What the form gained instead is **when**. Anonymity is a property of the
consultation, not of how soon it happens, and a patient who wanted to speak to
somebody under an alias on Thursday was previously obliged to give up the alias
to do it. `ConsultOptionKind` on the session routes the two: instant goes to
matching, scheduled to the listing and the slot picker, and the alias and the
concern ride along either way.

## A search that outlives its screen

Tapping Instant Consultation opened a full-screen search, and backing out of it
threw the search away — silently, with the patient returned to a dashboard that
mentioned none of it.

`DoctorSearchSession` is the fix: one object for the whole app, registered as a
lazy singleton, holding the search. The matching screen is a *view* of it, the
dashboard renders `DoctorSearchCard` from it, and leaving the screen backgrounds
the search rather than ending it — "Finding a doctor", then "3 doctors found",
and a tap opens them.

The distinction that makes this safe is the one the matching screen already drew
and now acts on:

| | files a record | rings a doctor | leaving the screen |
| --- | --- | --- | --- |
| **discovery** (on the way to a listing) | no | no | backgrounds it |
| **a request** (a doctor is chosen) | yes | yes | withdraws it |

A request left running in the background is somebody being rung for a call
nobody is waiting on, which is why only the first is backgrounded.

One mechanical detail worth keeping: the session defers `notifyListeners` out of
the build phase. It is poked from `initState` — the search screen starts a search
as it mounts, while the dashboard underneath is already listening — and a plain
notify there marks an already-built `ListenableBuilder` dirty mid-build, which
Flutter asserts on.

## Reviews, and what a doctor may claim

The feedback screen existed, collected stars, chips and a note, and ended at a
`TODO`. Every review a patient left was discarded — which is why no doctor's
profile had one, and why the star on a listing card was an average over nothing
a patient could read.

It is now reached from the **end of the call** rather than from the moment a
doctor was found, which was before a word had been said and carried no
consultation for a rating to belong to. `POST /consultations/:id/rate` stores
it, and `GET /doctors/:id` carries the recent ones onto the profile.

Three rules the review holds to:

- **The doctor's stars and the call's are separate figures.** Only `rating`
  feeds `DoctorRating`. A dropped call is our network, and charging a doctor for
  it is how a star rating stops meaning anything.
- **A reviewer is not named.** Every review reads `Verified patient`. A
  patient's name is not something the directory hands out, and an anonymous
  consultation's alias is not either — attaching an alias to a doctor and a date
  is the one thing anonymity here promises not to do. The label is also true:
  only a completed consultation can be rated.
- **Only reviews with words are listed.** A rating on its own is in the average
  already, and a wall of empty five-star rows pushes the one review with
  something to say off the screen.

Alongside them, a doctor may now add **certificates** to their own profile — a
fellowship, a diploma, a specialist board. Each is a title plus a file, and the
title is the claim: it is what patients read, and it is what a reviewer is
deciding on. Until one is accepted it is visible only to the doctor, marked
pending on their credentials screen, and `qualificationsOf` withholds it from
everything a patient can call. Nothing on a verified profile got there by being
typed.

Filing one does **not** re-open the registration — an approved doctor adding a
certificate is not asking to be approved again — which is exactly why the
console needed a certificate queue of its own: its registration queue is
filtered on application status and would never have shown one, so a doctor could
have waited forever for a review nobody was ever offered.

## Popular with nobody

The patient home screen opened on a row of four tiles headed **Popular
Specialities**. It was a constant in the app: the same four for everybody,
popular with nobody, and shown to somebody on the day they installed the app as
though it described them. Worse, the tiles filtered on ids the app had invented
— `cardiology` — against doctor records reading `Cardiology`, so every one of
them led to an empty list.

The section is now the patient's own, off their dashboard, derived from the
doctors they have actually consulted and ordered by how often. A new patient has
no answer yet, and the section is absent rather than filled with a guess.
`Speciality.named` builds one from a doctor's `specialty` verbatim, so the id is
the string the directory filters on and the tile leads somewhere.

## Profiles and dashboards

Both roles now have a full profile section and a full dashboard, and every row
on either leads to a screen. That is the rule the two nav bars are held to by
`doctor_home_screen_test.dart` and `patient_home_screen_test.dart`: each tab is
tapped and asserted to render without the words "coming soon". A bar that lies
about where it goes is worse than a short one, which is why Appointments,
Patients and Earnings were *removed* from the bars before their screens existed
and are back now that they do.

| Slice | Whose | What |
| --- | --- | --- |
| `features/appointments/` | both | One consultation list, read from either end |
| `features/doctor_practice/` | doctor | Profile edits, patients, earnings, payouts, documents, settings |
| `features/profile/` | patient | Account, medical record, notification settings, photo |
| `features/home/` | both | The two dashboards |

Three decisions worth not undoing:

**One appointment entity, not two.** A patient's list and a doctor's list are
the same consultation rows read from opposite ends. `Appointment` therefore
names `counterpartName` rather than `doctorName` or `patientName`, and
`AppointmentAudience` decides which endpoint is read and nothing else. Two
entities would be two mappers, two cards, and two chances for the doctor's list
to end up showing the doctor — which is exactly the bug the call screen had.

**A photo is not a public URL.** `GET /patients/me/photo` and
`GET /doctors/me/photo` sit behind the same bearer token as the record they
belong to, because a link anyone could open either expires and breaks or does
not expire and is a permanent leak of medical-account data. `Image.network`
sends no headers, so `core/widgets/remote_avatar.dart` exists to make the
request authenticated and to fall back to initials — for a missing photo, a slow
one, a broken one, and a signed-out app alike. A patient's photo reaches only
that patient: there is no route shaped to ask for somebody else's, so a doctor's
patient roster renders initials and says so.

**`features/doctor_practice/` is separate from `features/doctor_onboarding/`.**
Onboarding is the registration and the review — filing an application, watching
its status, the post-approval wizard. Practice is what a doctor changes
*afterwards*. The split matters because of what it forbids: the edit form cannot
touch the registration number, the medical degree or the specialty, since those
were read off a certificate a reviewer accepted and rewriting them would make
the approval meaningless. `UpdateDoctorProfileDto` on the API is where that list
lives; `ReviewedFieldsCard` is where the app explains it.

Two figures the app deliberately does not compute:

- **Earnings are gross.** No platform commission is configured anywhere in this
  project, and a percentage invented in code is a number a doctor plans against
  and is then paid less than. The earnings card says "before the platform's
  share" rather than showing a net figure nobody has decided.
- **Profile completeness is the server's.** `stats.profileCompleteness` comes
  from the API, because the app must not have to know which fields exist in
  order to know how many are missing — adding one would otherwise silently make
  every patient complete again.

## The post-approval wizard

An approved doctor is walked through two screens — their fees, then their hours
— and both are reachable again afterwards from their profile. That double life
is where both of the flow's bugs lived.

**A screen cannot work out why it was opened from the navigator stack.**
`SetAvailabilityScreen` decided where Save should go by asking
`navigator.canPop()`: pop back if there is something behind, otherwise hand
over to the doctor's home screen. But the wizard *pushes* availability on top
of the fee screen, so `canPop()` is true in both cases — and finishing
onboarding saved the schedule and then returned the doctor to the fee step. The
write had gone through and it looked exactly like a save that had not. Both
screens now take an explicit `isWizardStep`, and `canPop` is left to answer the
only question it can: whether popping is possible at all.

**Two prices, entered separately.** The fee step collected one amount and wrote
it to both `videoFee` and `audioFee`, so a doctor could not charge less for a
voice call — which is what nearly all of them want. It also offered four fixed
chips and no text field, so ₹450 was unsayable. It is now two fields with quick
picks under each, a "Same as video" shortcut, and either price may be left
blank — which the screen explains rather than blocking, because a doctor who
only does video is a real doctor.

Two smaller things the same pass fixed, both of which read as "it will not
save":

- **The fee options came from the backend.** A failed read left the screen with
  no chips, no value, a permanently disabled Continue and nothing said about
  why — the load's error was recorded and only the *save* handler ever looked
  at `errorMessage`. The options are presentation, so the app owns them, the
  form seeds the platform's suggestion, and every failure reaches a snackbar.
- **The use cases threw `ArgumentError`.** Controllers catch `Failure` for its
  message and everything else for the generic one, so an `ArgumentError` — with
  a perfectly good explanation inside it — arrived as "Something went wrong".
  `ManagePracticeSetup` and `ManageAvailability` throw `Failure` now.

And one rule that was too strict: availability required a day *and* a window
before it could be saved at all, so a doctor **turning themselves off** — the
thing the switch exists for — found Save disabled with "Pick at least one day."
Hours are required to go *online*; an empty schedule while offline is a
legitimate thing to record, and the API agrees.

## Whose name the call shows

One screen serves both ends of a consultation, so it cannot label itself from
the doctor — and it did. `CallArgs.fromConsultation` reads `isCaller`, which is
the API's answer to "which end is this device", and names the **peer**:

| `isCaller` | Whose device | `displayName` | `displaySubtitle` |
| --- | --- | --- | --- |
| true | the patient's | the doctor | their speciality |
| false | the doctor's | the patient | `Patient` / `Anonymous patient` |

The video header was fixed first. The audio screen was not: it took the
consultation's `Doctor` and rendered that name, that speciality and that initial
at 24pt, so a doctor on a voice call spent it looking at their own name — and
the patient saw the right one only by coincidence. `_AudioCallAvatarBackground`
now takes a name, a subtitle and initials rather than a `Doctor`, because on the
doctor's phone the other end is a patient and there is no `Doctor` that
describes them. `test/features/call/presentation/call_args_test.dart` asserts
the invariant directly: the two ends never label themselves the same way.

## The admin console

The console is a separate Next.js project rather than a screen in this app,
because reviewing credentials is a desktop job: dense sortable tables,
side-by-side document viewing, copyable registration numbers. It shares this
app's palette and type scale — ported into its own `src/app/globals.css` — and
the same three-layer feature slices, so a feature looks the same in both.

The rule it enforces: a registration is approved only once **every required
document has been accepted on its own**. `AdminQueueScreen` here remains as a
mobile view of the application-level decision; per-document review lives in the
console, where there is room to read a document properly.

## One number, one journey

A phone number belongs to one person, and one person is either consulting or
being consulted. Nothing enforced that: the landing screen's role tap was the
only thing deciding which app you entered, so the same number could open both.
A patient who tapped **Doctor** was walked into doctor registration; a doctor
who tapped **Patient** was handed the patient dashboard. The result was two
half-built accounts on one identity and a consultation record with nobody real
on one end of it.

`ResolveStartDestination` is the gate, and it is the gate for both entry points
— the cold launch and the OTP screen call the same method, so the two cannot
disagree. A mismatch answers `StartDestination.roleConflict`; the caller ends
the session and returns to the landing screen with the explanation. Ending it
matters: a refused journey that leaves a token behind is one restart away from
being the journey the app opens on.

Two things the gate is careful about, both of which were the old bug in
miniature:

- **A failed lookup is not an answer.** `_DoctorLookup` and `_PatientLookup`
  say "no", "yes" and "I could not tell" separately. The patient check reports
  `true` when it *fails* — deliberately, so a patient with no signal still
  reaches their dashboard — and a conflict is raised only when the lookup
  actually answered. Otherwise a flaky connection would lock a real doctor out
  of their own registration.
- **The doctor app is gated on the review, not on the tap.** The only route to
  `doctorHome` is an approved application. A lookup that fails now sends a
  doctor to `doctorSetup` rather than to their dashboard — the dashboard could
  show a retry, which is why it used to be the fallback, but it is also the
  doctor app, and handing it to somebody whose approval could not be confirmed
  is exactly what this exists to prevent. The setup screen re-reads the
  application and moves them on if there is one.

## The certificate is the registration

The upload step carried a **Skip**, and the details behind it could be typed by
hand. So a doctor could enter a registration number they had invented, file the
form, and hold an account whose credentials no reviewer had ever seen a document
for. There is nothing to skip *to*: without a certificate there is nothing to
approve.

`DoctorSetupController.isStepComplete` now requires a file, `UploadStep` carries
a Continue that is disabled until there is one and says what unlocks it, and
`SubmitDoctorApplication` takes a **required** `MedicalCertificate` — so filing
without one is a compile error rather than a registration a reviewer cannot act
on. PDF, JPG and PNG are all accepted, as they always were; the card states the
limit and `MedicalCertificate.mimeType` is what makes the upload declare a type
the API's allowlist recognises.

Leaving the flow was broken in a way that looked like a dead button.
`DoctorProfileSetupScreen` is pushed with `pushNamedAndRemoveUntil(..., (route)
=> false)`, so there is no route underneath it — and back called `maybePop()`,
which did nothing. The system gesture closed the app instead, and a doctor who
opened registration by mistake had no way out but killing it. Back now steps
through the wizard and, from the first step, offers to leave for the login
screen. The session goes with it: a half-filed registration left signed in would
drop them straight back here on the next launch. A `PopScope` routes the system
gesture through the same handler.

## "Too many requests", and why reinstalling did not help

The OTP resend cooldown was a constant compiled into the app — thirty seconds —
while the gateway throttles the **phone number**. Reinstalling clears nothing,
which is why the lockout survived it. Worse, a local timer shorter than the
server's window brought the Resend button back to life at the exact moment the
next request was certain to be refused, and on most SMS gateways a refused send
still counts against the window. The app was keeping its own lockout alive.

Three changes, and all three are needed:

- **The server's number travels with the id.** `OtpChallenge` carries
  `resendAfter` from `resendAfterSeconds`, and the screen counts that down.
- **A refusal is recognised.** `Failure` carries the API's `code` and a
  `retryAfter`, and `ApiClient` trusts a 429 status where no code was sent.
  `Failure.isRateLimited` falls back to the message for gateways that answer
  with prose, which is the case that left the screen retrying blind.
- **The next request is held before it is made.** `PhoneLoginController` keeps
  the next allowed time per number in a static map, because it has to outlive
  the controller — a fresh controller must not hand out a request the gateway
  is going to refuse. `configureDependencies` clears it, which is a fresh
  process in every case that matters.

## The design system

The palette is Neslife's dark teal: `#1B7B80` into `#246D74`, the two stops of
`AppColors.brandGradient`. Every brand token is derived from that pair, so the
gradient on a nav bar, the fill of a primary button and the tint behind a badge
read as one family rather than three near-misses. Names stay semantic
(`primaryDeep`, not `teal900`): what a colour is *for* survives a rebrand.

Three shared components came out of this, and each replaced something that had
been written per screen:

**`AppBottomNavBar`.** The two roles had separately written bars that had
drifted apart — one animated and pill-backed, the other a static row with a top
border — so crossing from the patient app to the doctor app felt like crossing
between two products. One bar now, generic over the tab type. The selected
destination expands into a gradient pill carrying its own label and the others
are icons, which is what removed four permanent captions from the bottom of
every screen and the need to set "Appointments" a point smaller to fit a quarter
of a 320pt phone. Widths are **computed, not flexed**: flex hands every child an
equal share, and the selected item needs about twice that — which is how the
first version overflowed by 23 pixels at 320pt.

**`AppSnackBar`.** Messages were built at each call site, so the most important
ones in the app — a call that could not connect, a payment that did not go
through — looked exactly like the least important. Colour carries the outcome
now, duration follows the kind (a failure names something to do and stays up
long enough to act on), and every entry point hides the current bar first.

**`AppConfirmDialog`.** Confirmations were bare `AlertDialog`s with two text
buttons, so logging out was two identical-looking words in a corner with nothing
to say which was the way out. The destructive choice is a filled button under a
tinted glyph; Cancel is the quiet one underneath, which is the right way round
for something a mis-tap cannot undo.

`ProfileHeroHeader` is shared for the same reason the nav bar is: the two
profiles were doing the same job and looking like different apps.

## Instant and scheduled

`ConsultOptionKind.immediate` and "Immediate Consultation" were the app's own
name for what every other surface called instant. It is `instant` throughout
now.

They are also genuinely different things to a patient — one is "I need a doctor
now", the other is "I have an appointment on Thursday" — and the appointment
list mixed them, so a booking three days out sat between two calls that had
already happened. `AppointmentKind` separates them, and the list asks **two**
questions on two axes:

- **When** — `AppointmentFilter`, which is the expensive axis and is asked of
  the API. Its `upcoming` case was labelled "Active", which was wrong in both
  directions: it excluded a booking on Thursday and read as "happening right
  now" for a request that was only queued.
- **What kind** — `AppointmentKindFilter`, answered locally, because the kind is
  a property of rows already in memory and switching chips should not cost a
  round trip.

One control mixing the two could not express "my scheduled appointments that
have not happened yet", which is the main thing the screen is opened for. With
no kind selected the rows are grouped under both headings; with one selected the
heading would only repeat the chip, so it goes.

`AppointmentKind.from` is deliberately tolerant — `kind`, `type`, or the
presence of a booked time — because the two API processes have disagreed, and a
booking that parses as instant is a booking whose time is never shown.

The doctor's dashboard had the same blind spot from the other end: it listed the
rest of the current day and nothing else, so a doctor with a clear afternoon and
a full Thursday opened the app to "Nothing booked". `DoctorDashboard.appointmentDays`
cuts the whole schedule ahead into labelled days — Today, then Tomorrow, then
each date — and sorts before grouping, because one row out of sequence would
open a second "Today" further down the list. `DoctorAppointment.isJoinable` is
scoped to today as well: a booking three days out can be `confirmed` and is not
something to open a room for.

## Reading a doctor before calling one

There was no doctor profile. Tapping a doctor on the dashboard **filed a
consultation and rang them on the spot**, so there was no way to look at
somebody without calling them: the entire basis for choosing who to discuss your
health with was a name, a star and a fee, and a mis-tap was a call to a stranger.

`DoctorDetailScreen` is that screen. It opens on the listing row it was handed —
name, speciality and fee are on screen immediately — and fills in the
description, qualifications, languages and the count behind the star as they
arrive. A profile that spends a second as a spinner is one people back out of
before it arrives, and everything needed to *recognise* the doctor is already in
hand. `Doctor.mergedWith` is what folds the two together without a missing field
blanking what was already shown.

Two things the screen states that the listing could not: both fees, because a
doctor may charge less for a voice call and there was no way to find that out
before committing to a mode; and which call types they do **not** take, said
outright rather than discovered when the mode sheet refuses.

## Anonymous consultations

An anonymous consultation is an ordinary one whose patient is named by an alias.
It was built as a parallel flow, and the flow ended nowhere: `startSession` was a
stub that returned `anon-<timestamp>`, wrote nothing anywhere, and handed over to
a doctor listing and then a chat thread against another stub. No consultation
record existed, no doctor was ever rung, and the alias the patient chose never
left the device.

`POST /consultations/instant` already takes `isAnonymous` and `alias`, so there
was never a second record to open. The booking form now collects the alias and
hands it to the same matchmaking path every other instant consultation takes;
`AnonymousSession` is the answers from the form on their way to that call rather
than a backend handle. What is left of the feature's own data layer is the alias
suggestion, which is reference data the app owns — and uniqueness is not checked
because keeping a register of aliases is the one thing anonymity must not do.

## The audio call

The voice call was a video call with the camera off, and it showed.

**The audio route was never set.** `CallSession` defaulted `isSpeakerOn` to true
and nothing ever told the platform, so the button said "speaker" while the sound
came out of the earpiece — and the first tap of it appeared to do nothing,
because it was switching *away* from a state the phone had never been in. The
route is applied when the stream opens now, and the default differs by call type:
a video call is held at arm's length and belongs on the speaker, a voice call is
held to the ear and does not. `CallController.toggleSpeaker` flips the flag only
once the platform has actually switched, so a refused route change does not light
up a button for an output nothing is coming from.

**Retry could only ever fail.** `startSession` left `_connected`, the candidate
cursor and the two handshake flags set from the previous attempt, so a second
attempt began believing it had already answered an offer — and never answered the
new one. It looked like the network and it was the app. `closeSession` runs first
now, and it clears `_connected`, which it had been missing.

**The screen said "Calling..." for every state that was not connected**, so a
call that had failed to negotiate, one that had dropped and was reconnecting, and
one that had already ended all looked identical — and all three looked like a
phone ringing somewhere. Each state is named, the avatar ring pulses while the
call is being set up and settles when it is, and mute and route are restated
where they can be read from across a room: a voice call is the one screen people
look away from, and "why can they not hear me" is the most common thing to go
wrong on one.

The controls bar names every button. A row of unlabelled circles on black is
guesswork under pressure, and hanging up was the same size and shape as mute.
The speaker control is a speaker/earpiece pair rather than volume-up and
volume-down, which described loudness — a thing it does not change.
