import admin from 'firebase-admin';

// Initialize Firebase Admin once
if (!admin.apps.length) {
  const serviceAccount = JSON.parse(
    Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf-8')
  );

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id,
  });
}

const db = admin.firestore();

export default async function handler(req, res) {
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
    console.log('✅ Body received:', body);

    const { firebaseJWT, field, value } = body;

    // Your validation and update logic here
    return res.status(200).json({ value });
  } catch (err) {
    console.error('❌ JSON parse error:', err);
    return res.status(400).json({ error: 'Invalid JSON or request' });
  }
}
