import admin from 'firebase-admin';

// Decode Firebase service account from base64 env var
const serviceAccount = JSON.parse(
  Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf-8')
);

// Initialize Firebase Admin SDK once
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id,
  });
}

const db = admin.firestore();

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  let rawBody = '';

  // Collect raw data chunks
  req.on('data', (chunk) => {
    rawBody += chunk;
  });

  req.on('end', async () => {
    let body;
    try {
      body = JSON.parse(rawBody);
    } catch {
      return res.status(400).json({ error: 'Invalid JSON body' });
    }

    const { firebaseJWT, field, value } = body;

    if (!firebaseJWT || !field || value === undefined) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    try {
      const decoded = await admin.auth().verifyIdToken(firebaseJWT);
      const docId = decoded.uid;

      const docRef = db.collection(process.env.DEFAULT_COLLECTION_NAME).doc(docId);

      await docRef.set({ [field]: value }, { merge: true });

      return res.status(200).json({ success: true, docId, field, value });
    } catch (err) {
      console.error(err);
      return res.status(500).json({ error: 'Failed to update field', details: err.message });
    }
  });

  req.on('error', (err) => {
    return res.status(500).json({ error: 'Error reading request body', details: err.message });
  });
}
