// /api/update-field.js
import { db, decodeFirebaseToken, defaultCollectionName } from './_utils/firebaseAdmin'; // Adjust path if needed

export default async function handler(req, res) {
  // --- Assuming CORS and OPTIONS are handled by vercel.json ---
  console.log(`[update-field] Setting aggressive CORS headers for ${req.method} request to ${req.url}`);
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*'); // Most permissive
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS, PUT, DELETE, PATCH');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, X-CSRF-Token, Accept-Version, Content-Length, Content-MD5, Date, X-Api-Version, baggage, sentry-trace'); // Very permissive
  res.setHeader('Vary', 'Origin, Access-Control-Request-Headers, Access-Control-Request-Method'); // Good practice for CORS

  console.log(`[update-field] Request received: Method=${req.method}, URL=${req.url}`);
  console.log('[update-field] Request Headers:', JSON.stringify(req.headers, null, 2));
  // ---

  console.log(`[/api/update-field] Request: ${req.method} ${req.url}`);

  const body = req.body;
  console.log('[/api/update-field] Parsed req.body:', JSON.stringify(body));

  if (!body || Object.keys(body).length === 0) {
    return res.status(400).json({ error: 'Request body is missing or empty.' });
  }

  const { firebaseJWT, field, value } = body; // Assuming docId is derived from JWT (UID)

  if (firebaseJWT === undefined || field === undefined || value === undefined) {
    return res.status(400).json({ error: 'Missing required fields: firebaseJWT, field, value.' });
  }
  if (typeof field !== 'string' || field.trim() === "") {
    return res.status(400).json({ error: 'Invalid field (must be a non-empty string)' });
  }

  if (!defaultCollectionName) {
    console.error("[/api/update-field] Server configuration error: DEFAULT_COLLECTION_NAME not set.");
    return res.status(500).json({ error: 'Server configuration error.' });
  }
  if (!db) {
    console.error("[/api/update-field] Server error: Firestore DB instance not available.");
    return res.status(503).json({ error: 'Firestore service unavailable.' });
  }

  try {
    const decodedToken = await decodeFirebaseToken(firebaseJWT);
    if (!decodedToken || !decodedToken.uid) {
      return res.status(401).json({ error: 'Authentication failed. Invalid or expired token.' });
    }
    const userUid = decodedToken; // This is your effective docId

    const docRef = db.collection(defaultCollectionName).doc(userUid);
    const currentDoc = await docRef.get(); // Check if doc exists for accurate messaging
    let actionMessage = "";

    if (currentDoc.exists) {
      actionMessage = `Field '${field}' in document '${userUid}' (collection '${defaultCollectionName}') updated.`;
    } else {
      actionMessage = `Document '${userUid}' created in collection '${defaultCollectionName}' with field '${field}'.`;
    }

    console.log(`[/api/update-field] Attempting to set/merge for user UID '${userUid}': field '${field}' to '${JSON.stringify(value)}'`);

    await docRef.set({ [field]: value }, { merge: true }); // Creates or merges

    return res.status(200).json({
      success: true,
      message: `(Admin SDK) ${actionMessage}`,
      docId: userUid,
      field: field,
      newValue: value,
      operation: currentDoc.exists ? 'updated' : 'created',
    });

  } catch (error) {
    console.error('[/api/update-field] Error processing request:', error.name, error.message, error.code);
    if (error.code && error.code.startsWith('auth/')) {
        return res.status(401).json({ error: 'Authentication processing error.', details: error.message });
    }
    // Add more specific Firestore error checks if needed
    return res.status(500).json({ error: 'Internal server error while updating Firestore.', details: error.message });
  }
}