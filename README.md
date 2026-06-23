# yatty

Appointment scheduling for tattoo artists. Artists create an account, build a
customizable booking form, and share its link. Clients open the link (no account
needed), fill out the form, pick an open slot, and book — without ever
double-booking the artist. Bookings land on the artist's in-app calendar, and
both sides can add the appointment to their device calendar via `.ics`.

Built with **Flutter** (web first, iOS-ready) and **Firebase** (Auth +
Firestore + Hosting). No Cloud Functions, so it runs on the free Spark plan.

## How it works

- **Only artists authenticate** (email/password). Clients are anonymous.
- An artist sets **weekly availability** + minimum booking notice.
- A **booking form** has a title, description, appointment length, and any
  custom questions (placement, size, references…). Its document id is the public
  slug: `/book/{formId}`.
- The public booking page computes **open slots** = availability − existing
  appointments, so clients can only pick free times.
- Each appointment uses a **deterministic id** (`{artistId}__{startMillis}`) and
  is written in a **transaction**, so two people grabbing the same slot collide
  and the second one fails — no double-booking.

### Data model (Firestore)

| Path | Who can read | Who can write | Contents |
|------|--------------|---------------|----------|
| `artists/{uid}` | owner | owner | private profile (email) |
| `publicProfiles/{uid}` | anyone | owner | display name + availability |
| `forms/{formId}` | anyone | owner | booking form definition |
| `appointments/{id}` | anyone | create: anyone · edit: owner | artistId, formId, start, end, status — **no PII** |
| `appointments/{id}/private/details` | owner | create: anyone · edit: owner | customer name, email, phone, answers |

Customer PII lives only in the `private` subcollection that the public can never
read, which is why the parent appointment can be publicly readable (needed to
compute availability) without leaking anything.

## Develop

```bash
flutter pub get
flutter run -d chrome        # local dev
flutter test                 # scheduling logic tests
flutter analyze lib test
```

## Deploy

```bash
flutter build web
firebase deploy --only hosting,firestore:rules,firestore:indexes
```

Live site: https://yatty-cf0d5.web.app

## Roadmap

- iOS build (register the iOS app in Firebase, add its config to
  `lib/firebase_options.dart`, wire native `.ics` sharing in
  `lib/services/ics_download_stub.dart`).
- Client-side reschedule/cancel links.
- Email/SMS reminders (needs Blaze plan + a function or third-party).
