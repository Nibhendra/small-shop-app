const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const twilio = require('twilio');
require('dotenv').config();

const { getTwilioConfig } = require('./env');

const admin = require('firebase-admin');
const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');

const TWILIO_ACCOUNT_SID = defineSecret('TWILIO_ACCOUNT_SID');
const TWILIO_AUTH_TOKEN = defineSecret('TWILIO_AUTH_TOKEN');
const TWILIO_WHATSAPP_FROM = defineSecret('TWILIO_WHATSAPP_FROM');

admin.initializeApp();

const db = admin.firestore();

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

function normalizePhone(phone) {
  const p = String(phone || '').trim();
  if (!p.startsWith('+') || p.length < 8) {
    throw new Error('Phone must be in E.164 format, e.g. +919876543210');
  }
  return p;
}

function docIdForPhone(phone) {
  return crypto.createHash('sha256').update(phone).digest('hex');
}

function generateOtp() {
  // 6-digit numeric
  return String(Math.floor(100000 + Math.random() * 900000));
}

function hashOtp(otp, salt) {
  return crypto.createHash('sha256').update(`${otp}:${salt}`).digest('hex');
}

async function getOrCreateUserByPhone(phone) {
  try {
    const user = await admin.auth().getUserByPhoneNumber(phone);
    return user;
  } catch (e) {
    // If not found, create
    const user = await admin.auth().createUser({ phoneNumber: phone });
    return user;
  }
}

async function sendOtpViaTwilioWhatsApp({ phone, otp }) {
  const { accountSid, authToken, whatsappFrom } = getTwilioConfig();

  // Twilio expects WhatsApp addresses formatted like: "whatsapp:+919876543210"
  const to = `whatsapp:${phone}`;
  const from = whatsappFrom.startsWith('whatsapp:')
    ? whatsappFrom
    : `whatsapp:${whatsappFrom}`;

  const client = twilio(accountSid, authToken);

  // NOTE: Many WhatsApp Business setups require approved templates for OTP.
  // If your account requires templates, replace body with a template message
  // or use Twilio's template/content APIs.
  await client.messages.create({
    from,
    to,
    body: `Your verification code is: ${otp}`
  });
}

app.post('/otp/start', async (req, res) => {
  try {
    const phone = normalizePhone(req.body.phone);
    const channel = String(req.body.channel || '').toLowerCase();
    // Option A: WhatsApp OTP via backend, SMS OTP via Firebase Phone Auth in app.
    if (channel !== 'whatsapp') {
      return res.status(400).json({ error: 'channel must be whatsapp' });
    }

    const id = docIdForPhone(phone);
    const ref = db.collection('otp_requests').doc(id);
    const snap = await ref.get();

    const now = Date.now();
    const salt = crypto.randomBytes(16).toString('hex');
    const otp = generateOtp();
    const otpHash = hashOtp(otp, salt);

    // Basic anti-spam: 30s resend cooldown.
    if (snap.exists) {
      const data = snap.data() || {};
      const lastSentAt = data.lastSentAtMs || 0;
      if (now - lastSentAt < 30_000) {
        return res.status(429).json({ error: 'Please wait before requesting another OTP' });
      }
    }

    await ref.set(
      {
        phone,
        channel,
        otpHash,
        salt,
        attempts: 0,
        createdAtMs: now,
        lastSentAtMs: now,
        expiresAtMs: now + 5 * 60_000
      },
      { merge: true }
    );

    // Send via Twilio WhatsApp
    await sendOtpViaTwilioWhatsApp({ phone, otp });

    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

app.post('/otp/verify', async (req, res) => {
  try {
    const phone = normalizePhone(req.body.phone);
    const code = String(req.body.code || '').trim();
    if (code.length < 4) {
      return res.status(400).json({ error: 'Invalid code' });
    }

    const id = docIdForPhone(phone);
    const ref = db.collection('otp_requests').doc(id);
    const snap = await ref.get();
    if (!snap.exists) {
      return res.status(400).json({ error: 'OTP not found. Please request again.' });
    }

    const data = snap.data() || {};
    const now = Date.now();
    if ((data.expiresAtMs || 0) < now) {
      await ref.delete();
      return res.status(400).json({ error: 'OTP expired. Please request again.' });
    }

    const attempts = (data.attempts || 0) + 1;
    if (attempts > 5) {
      await ref.delete();
      return res.status(429).json({ error: 'Too many attempts. Please request again.' });
    }

    const expectedHash = data.otpHash;
    const salt = data.salt;
    const actualHash = hashOtp(code, salt);

    if (!expectedHash || actualHash !== expectedHash) {
      await ref.set({ attempts }, { merge: true });
      return res.status(400).json({ error: 'Incorrect OTP' });
    }

    // OTP verified -> sign in to Firebase using a custom token.
    const user = await getOrCreateUserByPhone(phone);
    const token = await admin.auth().createCustomToken(user.uid, {
      phone
    });

    await ref.delete();

    res.json({ token });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

exports.api = onRequest(
  {
    region: 'us-central1',
    secrets: [TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_WHATSAPP_FROM]
  },
  app
);
