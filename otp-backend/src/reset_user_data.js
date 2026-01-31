/*
  Reset a single user's Firestore data.

  Usage (PowerShell):

    cd otp-backend
    npm install

    # Option A: identify by UID
    $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"
    node src/reset_user_data.js --uid <firebase_uid>

    # Option B: identify by phone (E.164)
    $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"
    node src/reset_user_data.js --phone "+911234567890"

    # Option C: identify by email
    $env:GOOGLE_APPLICATION_CREDENTIALS = "C:\path\to\service-account.json"
    node src/reset_user_data.js --email "user@example.com"

  This deletes:
    users/{uid}
    users/{uid}/products/*
    users/{uid}/sales/*

  It does NOT delete Firebase Auth user accounts.
*/

const admin = require('firebase-admin');

function parseArgs(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) continue;
    const key = a.slice(2);
    const value = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : true;
    out[key] = value;
  }
  return out;
}

function normalizeEmail(email) {
  const e = (email || '').trim();
  return e ? e.toLowerCase() : null;
}

function normalizePhone(phone) {
  const p = (phone || '').trim();
  if (!p) return null;
  return p.replace(/[\s\-\(\)]/g, '');
}

async function deleteCollection(colRef, batchSize = 200) {
  while (true) {
    const snap = await colRef.limit(batchSize).get();
    if (snap.empty) return;

    const batch = admin.firestore().batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  }
}

async function resolveUid({ uid, email, phone }) {
  if (uid) return uid;

  const users = admin.firestore().collection('users');

  if (email) {
    const e = normalizeEmail(email);
    const q = await users.where('email_lower', '==', e).limit(2).get();
    if (q.empty) throw new Error('No user found for email.');
    if (q.size > 1) throw new Error('Multiple users found for email (unexpected).');
    return q.docs[0].id;
  }

  if (phone) {
    const p = normalizePhone(phone);
    const q = await users.where('phone_normalized', '==', p).limit(2).get();
    if (q.empty) throw new Error('No user found for phone.');
    if (q.size > 1) throw new Error('Multiple users found for phone (unexpected).');
    return q.docs[0].id;
  }

  throw new Error('Provide one of: --uid, --email, --phone');
}

async function main() {
  const args = parseArgs(process.argv);

  // Uses GOOGLE_APPLICATION_CREDENTIALS by default.
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });

  const uid = await resolveUid({
    uid: args.uid,
    email: args.email,
    phone: args.phone,
  });

  const userDoc = admin.firestore().collection('users').doc(uid);

  console.log(`Resetting Firestore data for uid=${uid} ...`);

  await deleteCollection(userDoc.collection('products'));
  await deleteCollection(userDoc.collection('sales'));
  await userDoc.delete();

  console.log('Done.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
