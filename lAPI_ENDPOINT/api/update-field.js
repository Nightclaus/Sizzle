// /api/update-field.js (or your specific file name)

// Helper function to set CORS headers
function setCorsHeaders(res) {
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  // IMPORTANT: For production, replace '*' with your specific Flutter Web app's origin
  // e.g., 'https://your-flutter-app.com'
  // You can also use an array of allowed origins if needed, but that requires more logic.
  res.setHeader('Access-Control-Allow-Origin', process.env.NODE_ENV === 'development' ? '*' : 'https://your-production-flutter-app-domain.com');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, PUT, DELETE, OPTIONS'); // Allow all methods your API might use
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization'); // Be generous with allowed headers initially
}

export default async function handler(req, res) {
  // Set CORS headers for all responses
  setCorsHeaders(res);

  // Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    // Preflight requests should return 204 No Content for Vercel, or 200 OK
    // Vercel often prefers 204 for OPTIONS.
    return res.status(204).end();
  }

  // Ensure method is POST (or PATCH if you intend to use it later)
  if (req.method !== 'POST') { // Change to PATCH if you are sending PATCH requests
    res.setHeader('Allow', ['POST']); // Or ['PATCH']
    return res.status(405).json({ error: `Method ${req.method} Not Allowed` });
  }

  // --- Your actual logic starts here ---
  // Make sure body parsing is handled (Vercel does this automatically for JSON if Content-Type is correct)
  const { firebaseJWT, field, value, docId /* If you add docId back */ } = req.body;

  // Validate required fields (adjust if docId is also required)
  if (!firebaseJWT || !field || value === undefined /* Allow null, but not undefined */ ) {
    return res.status(400).json({ error: 'Missing required fields: firebaseJWT, field, value are mandatory.' });
  }

  try {
    // TODO: Add your Firebase Admin SDK initialization if not already global
    // TODO: Verify firebaseJWT using Firebase Admin SDK
    // Example (you'll need to import and initialize admin):
    // const decodedToken = await admin.auth().verifyIdToken(firebaseJWT);
    // const uid = decodedToken.uid;
    // console.log(`Authenticated user UID: ${uid}`);

    // TODO: Your Firestore update logic using docId, field, and value
    // Example:
    // const docRef = db.collection('yourCollectionName').doc(docId); // Assuming you have docId
    // await docRef.update({ [field]: value });

    console.log(`Simulating update: docId (if provided), field='${field}', value='${JSON.stringify(value)}' for JWT snippet: ${firebaseJWT.substring(0,10)}...`);

    return res.status(200).json({ success: true, message: `Field '${field}' processed.`, value: value });

  } catch (error) {
    console.error('Error processing request:', error);
    if (error.code === 'auth/id-token-expired' || error.code === 'auth/argument-error') {
      return res.status(401).json({ error: 'Authentication failed. Invalid or expired JWT.', details: error.message });
    }
    return res.status(500).json({ error: 'Internal server error', details: error.message });
  }
}