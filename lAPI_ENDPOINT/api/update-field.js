// /api/update-field.js

// (Assuming CORS is handled by vercel.json or a setCorsHeaders function call at the top)
// import admin and db initialization if needed

export default async function handler(req, res) {
  // If not using vercel.json for CORS, call your setCorsHeaders(res) here.

  console.log('Received request:', req.method, req.url);
  console.log('Request headers:', JSON.stringify(req.headers)); // Check content-type

  if (req.method === 'OPTIONS') {
    // If using vercel.json for CORS, this might not even be hit for OPTIONS
    // as Vercel's edge might handle it. If inline, it's needed.
    console.log('Handling OPTIONS request');
    // setCorsHeaders(res); // Ensure headers are set for OPTIONS if handling inline
    return res.status(204).end();
  }

  if (req.method !== 'POST') {
    console.log(`Method ${req.method} not allowed.`);
    res.setHeader('Allow', ['POST']);
    return res.status(405).json({ error: `Method ${req.method} Not Allowed` });
  }

  // Vercel automatically parses req.body for 'application/json' content type
  const body = req.body;
  console.log('Parsed request body:', JSON.stringify(body));

  if (!body) {
    console.error('Request body is undefined after Vercel parsing.');
    return res.status(400).json({ error: 'Request body is missing or could not be parsed.' });
  }

  const { firebaseJWT, field, value, docId } = body; // Destructure from the parsed body

  if (firebaseJWT === undefined || field === undefined || value === undefined /* || docId === undefined */) {
    console.error('One or more required fields are undefined in the request body.', { firebaseJWT, field, value, docId });
    return res.status(400).json({ error: 'Missing one or more required fields: firebaseJWT, field, value are mandatory.' });
  }

  try {
    console.log(`Processing update: field='${field}', value='${JSON.stringify(value)}', jwtPresent=${!!firebaseJWT}`);
    // TODO: Firebase Admin SDK init, JWT verification, Firestore update logic
    // const decodedToken = await admin.auth().verifyIdToken(firebaseJWT);
    // const uid = decodedToken.uid;
    // ...
    // await db.collection("yourCollection").doc(docId).update({ [field]: value });

    return res.status(200).json({ success: true, message: `Field '${field}' processed.`, receivedValue: value });
  } catch (error) {
    console.error('Error during request processing:', error.message, error.stack);
    if (error.code && (error.code.startsWith('auth/') || error.code === 'app/invalid-credential')) { // More robust check for auth errors
      return res.status(401).json({ error: 'Authentication error.', details: error.message });
    }
    return res.status(500).json({ error: 'Internal server error.', details: error.message });
  }
}