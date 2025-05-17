// /api/update-field.js
// NO imports from _utils/firebaseAdmin.js for this extreme debug step yet.

export default async function handler(req, res) {
    // --- AGGRESSIVE CORS HEADERS - APPLY TO EVERY RESPONSE ---
    // Forcing these directly here to override any vercel.json doubts for this test
    console.log(`[update-field] Setting aggressive CORS headers for ${req.method} request to ${req.url}`);
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    res.setHeader('Access-Control-Allow-Origin', '*'); // Most permissive
    res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS, PUT, DELETE, PATCH');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept, X-CSRF-Token, Accept-Version, Content-Length, Content-MD5, Date, X-Api-Version, baggage, sentry-trace'); // Very permissive
    res.setHeader('Vary', 'Origin, Access-Control-Request-Headers, Access-Control-Request-Method'); // Good practice for CORS

    console.log(`[update-field] Request received: Method=${req.method}, URL=${req.url}`);
    console.log('[update-field] Request Headers:', JSON.stringify(req.headers, null, 2));

    if (req.method === 'OPTIONS') {
        console.log('[update-field] Responding to OPTIONS preflight request with 204.');
        return res.status(204).end();
    }

    if (req.method === 'POST') {
        console.log('[update-field] Received POST request.');
        // Vercel should auto-parse JSON if Content-Type is application/json
        const body = req.body;
        console.log('[update-field] Parsed req.body (by Vercel):', JSON.stringify(body, null, 2));

        if (!body || Object.keys(body).length === 0) {
            console.error('[update-field] ERROR: req.body is undefined, null, or empty.');
            return res.status(400).json({
                error: 'Request body is missing, empty, or not valid JSON. Ensure Content-Type is application/json from client.',
                receivedBody: body // Send back what was received
            });
        }

        // If we get here, body was parsed. Try to destructure.
        const { firebaseJWT, field, value } = body;
        if (firebaseJWT === undefined || field === undefined || value === undefined) {
            console.error('[update-field] ERROR: Destructuring failed. One or more fields undefined.', { firebaseJWT, field, value });
            return res.status(400).json({ error: 'Destructuring failed. Missing firebaseJWT, field, or value.', receivedBody: body });
        }

        console.log('[update-field] SUCCESS: Body parsed and destructured.', { firebaseJWT, field, value });
        return res.status(200).json({ success: true, message: 'Debug: Body received and parsed.', data: body });
    }

    // Fallback for other methods
    console.log(`[update-field] Method ${req.method} not explicitly handled. Responding 405.`);
    res.setHeader('Allow', ['POST', 'OPTIONS']);
    return res.status(405).json({ error: `Method ${req.method} Not Allowed` });
}