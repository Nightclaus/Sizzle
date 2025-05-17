// /api/get-field.js
// If using shared firebaseAdmin, import it:
// import { db, decodeFirebaseToken, defaultCollectionName } from './_utils/firebaseAdmin';

export default async function handler(req, res) {
    // --- AGGRESSIVE CORS HEADERS - APPLY TO EVERY RESPONSE ---
    // (You can make this a shared function later if you prefer)
    console.log(`[/api/get-field] Setting aggressive CORS headers for ${req.method} request`);
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    res.setHeader('Access-Control-Allow-Origin', '*'); // For development. Restrict in production.
    res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS, PUT, DELETE, PATCH');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, X-CSRF-Token, Accept-Version, Content-Length, Content-MD5, Date, X-Api-Version, baggage, sentry-trace');
    res.setHeader('Vary', 'Origin, Access-Control-Request-Headers, Access-Control-Request-Method');


    console.log(`[/api/get-field] Request received: Method=${req.method}, URL=${req.url}`);
    // It's useful to log headers for debugging, but can be verbose for every request in prod.
    // console.log('[/api/get-field] Request Headers:', JSON.stringify(req.headers, null, 2));

    if (req.method === 'OPTIONS') {
        console.log('[/api/get-field] Responding to OPTIONS preflight request with 204.');
        return res.status(204).end(); // Crucial: Successful response for OPTIONS
    }

    // Your Flutter client sends POST for get-field too
    if (req.method === 'POST') {
        console.log('[/api/get-field] Received POST request.');
        const body = req.body;
        console.log('[/api/get-field] Parsed req.body (by Vercel):', JSON.stringify(body, null, 2));

        if (!body || Object.keys(body).length === 0) {
            console.error('[/api/get-field] ERROR: req.body is undefined, null, or empty.');
            return res.status(400).json({ error: 'Request body is missing for get-field.' });
        }

        const { firebaseJWT, field /*, docId if you use it */ } = body;

        if (firebaseJWT === undefined || field === undefined) {
            console.error('[/api/get-field] ERROR: Destructuring failed. Missing firebaseJWT or field.');
            return res.status(400).json({ error: 'Missing required fields: firebaseJWT, field.' });
        }

        try {
            console.log(`[/api/get-field] Processing: field='${field}', jwtPresent=${!!firebaseJWT}`);
            // --- TODO: Add your actual Firebase Admin JWT verification and Firestore fetch logic ---
            // Example:
            // const decodedToken = await decodeFirebaseToken(firebaseJWT); // from your _utils
            // if (!decodedToken || !decodedToken.uid) {
            //    return res.status(401).json({ error: 'Authentication failed.' });
            // }
            // const userUid = decodedToken.uid;
            // const docRef = db.collection(defaultCollectionName).doc(userUid);
            // const docSnap = await docRef.get();
            // if (!docSnap.exists()) return res.status(404).json({ error: 'User document not found.' });
            // const data = docSnap.data();
            // if (data === undefined || !(field in data)) return res.status(404).json({ error: `Field '${field}' not found.`});
            // const fieldValue = data[field];
            // ---

            const simulatedFieldValue = `Value of ${field} from GET endpoint`; // Replace with actual data
            return res.status(200).json({ success: true, value: simulatedFieldValue });

        } catch (error) {
            console.error('[/api/get-field] Error during processing:', error.name, error.message);
            // Add specific error handling (e.g., for JWT errors)
            return res.status(500).json({ error: 'Internal server error.', details: error.message });
        }
    }

    // Fallback for other methods
    console.log(`[/api/get-field] Method ${req.method} not explicitly handled. Responding 405.`);
    res.setHeader('Allow', ['POST', 'OPTIONS']);
    return res.status(405).json({ error: `Method ${req.method} Not Allowed on /api/get-field` });
}