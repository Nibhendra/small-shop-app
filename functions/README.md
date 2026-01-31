# Cloud Functions (Twilio WhatsApp OTP)

This folder contains a Firebase Cloud Functions backend that:

- Generates OTP codes
- Sends OTP via **WhatsApp** (Twilio)
- Verifies OTP and signs users into Firebase using **Custom Tokens**

## What you need

- Firebase project
- Firebase CLI installed (`npm i -g firebase-tools`)
- Twilio WhatsApp enabled (Sandbox or Business)

Note: In **Option A**, SMS OTP is handled by Firebase Phone Auth directly in the Flutter app (no backend).

## Configure secrets / env

The function reads these environment variables, and on deploy it expects them as Firebase Functions v2 **secrets**.

Important: Functions secrets require the Firebase **Blaze** plan. If you can't upgrade, use the standalone backend in `otp-backend/` instead.

- `TWILIO_ACCOUNT_SID`
- `TWILIO_AUTH_TOKEN`
- `TWILIO_WHATSAPP_FROM` (example: `whatsapp:+14155238886`)

Set them (recommended):

- `firebase functions:secrets:set TWILIO_ACCOUNT_SID`
- `firebase functions:secrets:set TWILIO_AUTH_TOKEN`
- `firebase functions:secrets:set TWILIO_WHATSAPP_FROM`

Then deploy:

- `firebase deploy --only functions`

How you set env depends on how you deploy:
- If using Firebase Functions config/secrets, map them accordingly.
- If testing locally, you can export them in your shell.

## Deploy (high level)

From repo root:

1. Initialize Firebase in this repo:

- `firebase init functions` (choose JavaScript)
- Point it to this `functions/` directory or copy these sources into Firebase's generated `functions` folder.

2. Install deps:

- `cd functions`
- `npm install`

3. Deploy:

- `firebase deploy --only functions`

## Endpoints

The deployed HTTPS function exposes:

- `POST /otp/start` `{ phone: "+91...", channel: "whatsapp" }`
- `POST /otp/verify` `{ phone: "+91...", code: "123456" }`

On verify success, it returns `{ token: "<firebase_custom_token>" }`.
