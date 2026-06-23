# yatty

Appointment scheduling for tattoo artists. Artists create an account, build a
customizable booking form, and share its link. Clients open the link (no account
needed), fill out the form, pick an open slot, and book — without ever
double-booking the artist. Bookings land on the artist's in-app calendar, and
both sides can add the appointment to their device calendar via `.ics`.

Built with **Flutter** (web first, iOS-ready) and **Firebase** (Auth +
Firestore + Hosting + Functions + Storage). After booking, an optional AI
design consult (GPT‑4o + gpt-image-1, proxied through Cloud Functions) helps the
client describe their tattoo and generates a concept image for the artist.

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

## AI design consult

After a client books, `DesignChatScreen` opens a chat backed by two callable
Cloud Functions in `functions/` (the **OpenAI key lives only here**, in Secret
Manager — never in the app):

- `aiChat` — GPT‑4o (vision) asks about idea/style/size/placement and reacts to
  uploaded reference photos.
- `aiGenerateConcept` — summarises the chat into an artist brief and generates a
  concept image with `gpt-image-1`. Brief + images are written (Admin SDK) to
  `appointments/{id}/private/design` and Firebase Storage; the artist sees them
  in the appointment details.

Guards: each call must reference a real appointment created in the last 6h, and
per-appointment usage is capped. For production, also enable **Firebase App
Check** to stop scripted abuse of the public endpoints.

## Deploy

```bash
flutter build web
firebase deploy --only hosting,firestore:rules,firestore:indexes,storage,functions
```

### Ops notes
- **OpenAI key**: stored as the `OPENAI_KEY` secret —
  `firebase functions:secrets:set OPENAI_KEY` (then redeploy functions). Rotate
  by setting a new version.
- **Public function access**: the booking page calls the functions
  unauthenticated, so each 2nd‑gen function's Cloud Run service needs
  `roles/run.invoker` for `allUsers`. Re-grant after creating *new* functions:
  `gcloud run services add-iam-policy-binding <svc> --region us-central1 --member=allUsers --role=roles/run.invoker`.
- Requires the **Blaze** (pay-as-you-go) plan for Functions/Storage.

Live site: https://yatty-cf0d5.web.app

## Roadmap

- iOS build (register the iOS app in Firebase, add its config to
  `lib/firebase_options.dart`, wire native `.ics` sharing in
  `lib/services/ics_download_stub.dart`).
- Client-side reschedule/cancel links.
- Email/SMS reminders (needs Blaze plan + a function or third-party).
