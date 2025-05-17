// /api/your-endpoint.js

function setSuperPermissiveCorsHeaders(res) {
    res.setHeader('Access-Control-Allow-Credentials', 'true'); // Allows cookies/auth headers if needed
    res.setHeader('Access-Control-Allow-Origin', '*');         // << THE KEY: Allow ANY origin
    res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT'); // Allow all common methods
    res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization, baggage, sentry-trace'); // Allow a wide range of headers
    console.log('Super permissive CORS headers set.');
}

export default async function handler(req, res) {
    setSuperPermissiveCorsHeaders(res); // Apply to all responses from this function

    if (req.method === 'OPTIONS') {
        console.log('Handling OPTIONS request with permissive CORS.');
        return res.status(204).end(); // Respond to preflight
    }

    // Your actual API logic for POST, GET, etc.
    // For example, for your update-field:
    if (req.method === 'POST') {
        const body = req.body;
        if (!body || Object.keys(body).length === 0) {
            return res.status(400).json({ error: 'Request body is missing or empty.' });
        }
        const { firebaseJWT, field, value } = body;
        if (firebaseJWT === undefined || field === undefined || value === undefined) {
            return res.status(400).json({ error: 'Missing required fields.' });
        }
        console.log(`Processing: ${field} = ${value}`);
        // ... your logic ...
        return res.status(200).json({ success: true, message: 'Processed' });
    }

    // Handle other methods or return 405
    res.setHeader('Allow', ['POST', 'OPTIONS']);
    return res.status(405).json({ error: `Method ${req.method} Not Allowed` });
}