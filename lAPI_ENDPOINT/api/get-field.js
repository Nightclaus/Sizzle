export default async function handler(req, res) {
  if (req.method !== 'PATCH') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  let body = req.body;
  if (!body) {
    try {
      body = JSON.parse(req.rawBody || req.bodyRaw || '{}');
    } catch {
      return res.status(400).json({ error: 'Invalid JSON body' });
    }
  }

  const { firebaseJWT, field, value } = body;  // use `body` here, not req.body

  try {
    const decoded = await admin.auth().verifyIdToken(firebaseJWT);
    const docId = decoded.uid;

    const docRef = db.collection(process.env.DEFAULT_COLLECTION_NAME).doc(docId);

    // Use set with merge: true to update or add the field
    await docRef.set({ [field]: value }, { merge: true });

    return res.status(200).json({ success: true, docId, field, value });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Failed to update field', details: err.message });
  }
}
