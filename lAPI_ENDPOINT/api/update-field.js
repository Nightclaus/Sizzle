// /api/update-field.js (when using vercel.json for CORS)

export default async function handler(req, res) {
  // NOTE: CORS headers and OPTIONS handling are now managed by vercel.json

  if (req.method !== 'POST') { // Or 'PATCH' if that's what your client sends
    res.setHeader('Allow', ['POST']);
    return res.status(405).json({ error: `Method ${req.method} Not Allowed` });
  }

  const { firebaseJWT, field, value, docId } = req.body;

  if (!firebaseJWT || !field || value === undefined /*|| !docId if required */) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    // TODO: Firebase Admin SDK init, JWT verification, Firestore update logic
    console.log(`Simulating update in vercel.json CORS mode: field='${field}', value='${JSON.stringify(value)}'`);
    return res.status(200).json({ success: true, message: `Field '${field}' processed (vercel.json CORS).`, value: value });
  } catch (error) {
    console.error('Error processing request:', error);
    // ... (same error handling as Method 1) ...
    return res.status(500).json({ error: 'Internal server error', details: error.message });
  }
}