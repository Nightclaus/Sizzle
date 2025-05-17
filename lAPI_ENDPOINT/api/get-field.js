import admin from 'firebase-admin';
import { db } from './yourFirebaseAdminInit'; // adjust as needed

export default async function handler(req, res) {
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
