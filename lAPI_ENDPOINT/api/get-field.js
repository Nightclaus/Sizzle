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

export default function handler(req, res) {
  let rawBody = '';

  req.on('data', (chunk) => {
    rawBody += chunk;
  });

  req.on('end', async () => {
    let body;
    try {
      body = JSON.parse(rawBody);
    } catch (err) {
      return res.status(400).json({ error: 'Invalid JSON', details: err.message });
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

      res.status(200).json({ success: true, docId, field, value });
    } catch (error) {
      console.error('Firebase verification or DB error:', error);
      res.status(500).json({ error: 'Failed to update field', details: error.message });
    }
  });

  req.on('error', (err) => {
    res.status(500).json({ error: 'Error reading request body', details: err.message });
  });
}
