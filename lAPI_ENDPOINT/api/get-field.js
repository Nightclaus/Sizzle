// /api/get-field.js
import { db, decodeFirebaseToken, defaultCollectionName } from './_utils/firebaseAdmin'; // Adjust path if needed

export default async function handler(req, res) {
  const body = req.body;
  console.log('/api/get-field - Parsed req.body:', JSON.stringify(body));

  if (!body || Object.keys(body).length === 0) {
    return res.status(400).json({ error: 'Request body is missing or empty.' });
  }

  const { firebaseJWT, field } = body;

  if (firebaseJWT === undefined || field === undefined) {
    return res.status(400).json({ error: 'Missing required fields: firebaseJWT, field.' });
  }
  if (typeof field !== 'string' || field.trim() === "") {
    return res.status(400).json({ error: 'Invalid field (must be a non-empty string)' });
  }

  if (!defaultCollectionName) {
    console.error("/api/get-field: DEFAULT_COLLECTION_NAME is not configured.");
    return res.status(500).json({ error: 'Server configuration error: Collection name not set.' });
  }
  if (!db) {
    console.error("/api/get-field: Firestore DB instance is not available.");
    return res.status(503).json({ error: 'Firestore (Admin SDK) not initialized.' });
  }

  try {
    const decodedToken = await decodeFirebaseToken(firebaseJWT);
    if (!decodedToken || !decodedToken.uid) {
      return res.status(401).json({ error: 'Authentication failed. Invalid or expired token.' });
    }
    const userUid = decodedToken.uid; // This is your docId

    const docRef = db.collection(defaultCollectionName).doc(userUid);
    const docSnapshot = await docRef.get();

    if (!docSnapshot.exists()) {
      console.log(`Document not found for UID: ${userUid}, collection: ${defaultCollectionName}`);
      return res.status(404).json({ error: `Document for user not found.` });
    }

    const data = docSnapshot.data();
    if (data === undefined || !(field in data)) { // Check if data is undefined or field doesn't exist
      console.log(`Field '${field}' not found in document for UID: ${userUid}`);
      return res.status(404).json({ error: `Field '${field}' not found in user's document.` });
    }

    console.log(`Retrieved field '${field}' for user UID '${userUid}'`);
    return res.status(200).json({
      success: true,
      message: `Retrieved field '${field}'.`,
      docId: userUid,
      field: field,
      value: data[field],
    });

  } catch (error) {
    console.error('Error in /api/get-field:', error.name, error.message, error.code);
    if (error.code && error.code.startsWith('auth/')) {
        return res.status(401).json({ error: 'Authentication processing error.', details: error.message });
    }
    return res.status(500).json({ error: 'Internal server error while retrieving Firestore field.', details: error.message });
  }
}