# WhatsApp OTP (Twilio) + SMS fallback (Firebase)

You **cannot** implement WhatsApp OTP in a Flutter-only client using Firebase Phone Auth.

- Firebase Phone Auth delivers OTP via **SMS**.
- WhatsApp OTP requires a **server-side** integration with a provider (Twilio WhatsApp, MessageBird, etc.).
- For security, the server must generate/verify OTP and issue a short-lived auth token to the app.

## Current option (recommended)

**Option A**

- WhatsApp OTP via backend (Twilio WhatsApp)
- SMS OTP via Firebase Phone Auth (built-in)

## Recommended flow (WhatsApp)

1. App asks backend: `POST /otp/start` with phone number and channel (`whatsapp`).
2. Backend generates OTP and sends it via Twilio WhatsApp.
3. App shows OTP entry screen and submits: `POST /otp/verify`.
4. Backend verifies OTP and returns a Firebase Custom Token.
5. App signs in: `FirebaseAuth.instance.signInWithCustomToken(token)`.
6. App continues to onboarding/profile completion and then uses Firestore normally.

## Why custom token?

It keeps Firebase Auth as the single identity system (so Firestore rules stay simple) while WhatsApp delivery/verification happens on your server.

## This repo

- Standalone backend (recommended if you can't use Blaze): [otp-backend/src/server.js](../otp-backend/src/server.js)
- Firebase Functions variant (requires Blaze for secrets): [functions/src/index.js](../functions/src/index.js)

Flutter calls backend using `--dart-define=OTP_API_BASE_URL=...`

- Example (standalone backend):
  - `flutter run --dart-define=OTP_API_BASE_URL=https://<your-backend-domain>`
- Example (Firebase Functions):
  - `flutter run --dart-define=OTP_API_BASE_URL=https://<region>-<project>.cloudfunctions.net/api`

## Backend environment variables

Twilio WhatsApp:

- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_WHATSAPP_FROM` (example: `whatsapp:+14155238886`)

## If you can't upgrade to Firebase Blaze

Firebase Functions secrets require the Blaze plan. If you can't upgrade, host the backend outside Firebase using [otp-backend/README.md](../otp-backend/README.md) and set the same variables in your hosting provider's environment variables UI.

Firebase Admin SDK (if not using default credentials):

- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

## Notes about templates

Many WhatsApp Business setups require approved templates for OTP. If your Twilio WhatsApp setup requires templates, replace the plain-text message body in the function with a template/content API.
