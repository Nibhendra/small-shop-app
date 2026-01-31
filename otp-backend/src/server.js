const crypto = require('crypto');
const express = require('express');
const cors = require('cors');
const twilio = require('twilio');
require('dotenv').config();

const admin = require('firebase-admin');

function requireEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function initFirebaseAdmin() {
  // Allow running on platforms that already provide Google credentials.
  // If explicit service-account env vars are present, use them.
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  const privateKey = process.env.FIREBASE_PRIVATE_KEY;

  if (projectId && clientEmail && privateKey) {
    admin.initializeApp({
      credential: admin.credential.cert({
        projectId,
        clientEmail,
        privateKey: privateKey.replace(/\\n/g, '\n')
      })
    });
    return;
  }

  admin.initializeApp();
}

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
  return String(Math.floor(100000 + Math.random() * 900000));
}

function hashOtp(otp, salt) {
  return crypto.createHash('sha256').update(`${otp}:${salt}`).digest('hex');
}

async function getOrCreateUserByPhone(phone) {
  try {
    return await admin.auth().getUserByPhoneNumber(phone);
  } catch (_) {
    return await admin.auth().createUser({ phoneNumber: phone });
  }
}

async function sendOtpViaTwilioWhatsApp({ phone, otp }) {
  const accountSid = requireEnv('TWILIO_ACCOUNT_SID');
  const authToken = requireEnv('TWILIO_AUTH_TOKEN');
  const whatsappFrom = requireEnv('TWILIO_WHATSAPP_FROM');

  const to = `whatsapp:${phone}`;
  const from = whatsappFrom.startsWith('whatsapp:')
    ? whatsappFrom
    : `whatsapp:${whatsappFrom}`;

  const client = twilio(accountSid, authToken);

  await client.messages.create({
    from,
    to,
    body: `Your verification code is: ${otp}`
  });
}

initFirebaseAdmin();
const db = admin.firestore();

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

app.get('/health', (_, res) => {
  res.json({ ok: true });
});

app.post('/otp/start', async (req, res) => {
  try {
    const phone = normalizePhone(req.body.phone);
    const channel = String(req.body.channel || '').toLowerCase();
    if (channel !== 'whatsapp') {
      return res.status(400).json({ error: 'channel must be whatsapp' });
    }

    const collection = process.env.OTP_COLLECTION || 'otp_requests';

    const id = docIdForPhone(phone);
    const ref = db.collection(collection).doc(id);
    const snap = await ref.get();

    const now = Date.now();
    const salt = crypto.randomBytes(16).toString('hex');
    const otp = generateOtp();
    const otpHash = hashOtp(otp, salt);

    if (snap.exists) {
      const data = snap.data() || {};
      const lastSentAt = data.lastSentAtMs || 0;
      if (now - lastSentAt < 30_000) {
        return res
          .status(429)
          .json({ error: 'Please wait before requesting another OTP' });
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

    const collection = process.env.OTP_COLLECTION || 'otp_requests';

    const id = docIdForPhone(phone);
    const ref = db.collection(collection).doc(id);
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

    const user = await getOrCreateUserByPhone(phone);
    const token = await admin.auth().createCustomToken(user.uid, { phone });

    await ref.delete();

    res.json({ token });
  } catch (e) {
    res.status(400).json({ error: String(e.message || e) });
  }
});

const port = Number(process.env.PORT || 8080);
app.listen(port, () => {
  // eslint-disable-next-line no-console
  console.log(`OTP backend listening on :${port}`);
});
