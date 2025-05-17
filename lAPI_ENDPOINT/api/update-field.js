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
  if (req.method === 'POST' || req.method === 'PATCH') {
    try {
      const body = typeof req.body === 'string' ? JSON.parse(req.body) : req.body;
      const { firebaseJWT, field, value } = body;

      // do stuff
      res.status(200).json({ ok: true, value });
    } catch (e) {
      console.error('Bad JSON:', e);
      res.status(400).json({ error: 'Invalid JSON' });
    }
  } else {
    res.status(405).json({ error: 'Method not allowed' });
  }
}
