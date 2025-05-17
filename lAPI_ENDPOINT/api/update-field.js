// ROOT/api/update-field.js
import admin from 'firebase-admin';

const serviceAccount = JSON.parse(
  Buffer.from(process.env.FIREBASE_SERVICE_ACCOUNT_BASE64, 'base64').toString('utf-8')
);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id,
  });
}

const db = admin.firestore();

export default async function handler(req, res) {
  let body = req.body;
  if (!body) {
    // Try to parse manually (if req.body undefined)
    try {
      body = JSON.parse(req.rawBody || req.bodyRaw || '{}');
    } catch {
      return res.status(400).json({ error: 'Invalid JSON body' });
    }
  }
  const { firebaseJWT, field, value } = req.body;

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
}
