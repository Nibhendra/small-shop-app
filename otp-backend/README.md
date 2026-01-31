# OTP Backend (Non-Firebase-Functions)

This is a standalone Node.js + Express backend that:

- Sends WhatsApp OTP via Twilio
- Stores OTP hashes in Firestore
- Verifies OTP and returns a Firebase Custom Token

It is designed for cases where you **cannot upgrade Firebase to Blaze**, so you can host the backend elsewhere (Render/Railway/VPS).

## Environment variables

Copy `.env.example` to `.env` and fill values.

Required:

- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_WHATSAPP_FROM` (example: `whatsapp:+14155238886`)
- `FIREBASE_PROJECT_ID`
- `FIREBASE_CLIENT_EMAIL`
- `FIREBASE_PRIVATE_KEY`

Notes:

- For `FIREBASE_PRIVATE_KEY`, paste it with newlines escaped (it often looks like `-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n`).

## Run locally

From repo root:

- `cd otp-backend`
- `npm install`
- `npm run dev`

Health check:

- `GET http://localhost:8080/health`

## Flutter app config

Run/build the app with:

- `--dart-define=OTP_API_BASE_URL=https://<your-backend-domain>`

The WhatsApp OTP button will call:

- `POST /otp/start`
- `POST /otp/verify`
