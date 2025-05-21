import { db, decodeFirebaseToken, defaultCollectionName } from './_utils/firebaseAdmin';

export default async function handler(req, res) {
  console.log(`[get-field] Setting CORS headers for ${req.method} request to ${req.url}`);
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, X-CSRF-Token, Accept-Version, Content-Length, Content-MD5, Date, X-Api-Version, baggage, sentry-trace');
  res.setHeader('Vary', 'Origin, Access-Control-Request-Headers, Access-Control-Request-Method');

  if (req.method === 'OPTIONS') {
    console.log('[get-field] Responding to OPTIONS preflight request with 204.');
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed. Use POST for retrieving fields.' });
  }

  console.log(`[/api/get-field] Request received: ${req.method} ${req.url}`);
  console.log('[get-field] Headers:', JSON.stringify(req.headers, null, 2));

  const body = req.body;
  console.log('[/api/get-field] Parsed req.body:', JSON.stringify(body));

  if (!body || Object.keys(body).length === 0) {
    return res.status(400).json({ error: 'Request body is missing or empty.' });
  }

  const { firebaseJWT, field } = body;

  if (!firebaseJWT || !field) {
    return res.status(400).json({ error: 'Missing required fields: firebaseJWT, field.' });
  }

  try {
    const decodedToken = await decodeFirebaseToken(firebaseJWT);
    if (!decodedToken || !decodedToken.uid) {
      return res.status(401).json({ error: 'Authentication failed. Invalid or expired token.' });
    }

    const userUid = decodedToken.uid;
    const docRef = db.collection(defaultCollectionName).doc(userUid);
    const docSnap = await docRef.get();

    if (!docSnap.exists) {
      return res.status(404).json({ error: `No document found for user UID '${userUid}'.` });
    }

    const docData = docSnap.data();

    if (!(field in docData)) {
      return res.status(404).json({ error: `Field '${field}' not found in user's document.` });
    }

    return res.status(200).json({
      success: true,
      docId: userUid,
      field: field,
      value: docData[field]
    });

  } catch (error) {
    console.error('[/api/get-field] Error processing request:', error.name, error.message, error.code);
    if (error.code && error.code.startsWith('auth/')) {
      return res.status(401).json({ error: 'Authentication error.', details: error.message });
    }
    return res.status(500).json({ error: 'Internal server error while retrieving Firestore data.', details: error.message });
  }
}
