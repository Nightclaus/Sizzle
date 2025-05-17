// /api/update-field.js
import { db, decodeFirebaseToken, defaultCollectionName } from './_utils/firebaseAdmin'; // Adjust path if needed

export default async function handler(req, res) {
  // CORS and OPTIONS are handled by vercel.json
  const body = req.body;
  console.log('/api/update-field - Parsed req.body:', JSON.stringify(body));


  if (!body || Object.keys(body).length === 0) {
    return res.status(400).json({ error: 'Request body is missing or empty.' });
  }

  const { firebaseJWT, field, value } = body;

  if (firebaseJWT === undefined || field === undefined || value === undefined) {
    return res.status(400).json({ error: 'Missing required fields: firebaseJWT, field, value.' });
  }
  if (typeof field !== 'string' || field.trim() === "") {
    return res.status(400).json({ error: 'Invalid field (must be a non-empty string)' });
  }

  if (!defaultCollectionName) {
    console.error("/api/update-field: DEFAULT_COLLECTION_NAME is not configured.");
    return res.status(500).json({ error: 'Server configuration error: Collection name not set.' });
  }
  if (!db) {
    console.error("/api/update-field: Firestore DB instance is not available.");
    return res.status(503).json({ error: 'Firestore (Admin SDK) not initialized.' });
  }

  try {
    const decodedToken = await decodeFirebaseToken(firebaseJWT);
    if (!decodedToken || !decodedToken.uid) {
      return res.status(401).json({ error: 'Authentication failed. Invalid or expired token.' });
    }
    const userUid = decodedToken.uid; // This is your docId

    const docRef = db.collection(defaultCollectionName).doc(userUid);
    const currentDoc = await docRef.get();
    let actionMessage = "";

    if (currentDoc.exists) {
      actionMessage = `Field '${field}' in document '${userUid}' (collection '${defaultCollectionName}') updated.`;
    } else {
      actionMessage = `Document '${userUid}' created in collection '${defaultCollectionName}' with field '${field}'.`;
    }

    console.log(`Attempting to set/merge for user UID '${userUid}': field '${field}' to '${JSON.stringify(value)}'`);

    await docRef.set({ [field]: value }, { merge: true });

    return res.status(200).json({
      success: true,
      message: `(Admin SDK) ${actionMessage}`,
      docId: userUid,
      field: field,
      newValue: value,
      operation: currentDoc.exists ? 'updated' : 'created',
    });

  } catch (error) {
    console.error('Error in /api/update-field:', error.name, error.message, error.code);
    // Check for specific Firebase/Firestore error codes if needed
    if (error.code && error.code.startsWith('auth/')) { // From decodeFirebaseToken or other auth ops
        return res.status(401).json({ error: 'Authentication processing error.', details: error.message });
    }
    return res.status(500).json({ error: 'Internal server error while updating Firestore.', details: error.message });
  }
}