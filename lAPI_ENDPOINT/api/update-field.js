// /api/update-field.js

// Assume firebase admin/db is initialized elsewhere or at the top of this file
// import admin from 'firebase-admin';
// import { getFirestore } from 'firebase-admin/firestore';
// if (!admin.apps.length) { /* ... initializeApp ... */ }
// const db = getFirestore();


// --- OPTION A: Inline CORS (if NOT using vercel.json for this route's CORS) ---
function setStandardCorsHeaders(res) {
    res.setHeader('Access-Control-Allow-Credentials', 'true');
    // IMPORTANT: Restrict this in production!
    res.setHeader('Access-Control-Allow-Origin', '*'); // Or process.env.YOUR_FLUTTER_WEB_APP_URL
    res.setHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS, PUT, DELETE, PATCH');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With, Accept'); // Add any other headers your client might send or server needs
    console.log('CORS headers set by setStandardCorsHeaders');
}

export default async function handler(req, res) {
    console.log(`--- New Request: ${req.method} ${req.url} ---`);
    console.log('Request Headers:', JSON.stringify(req.headers, null, 2));

    // Apply CORS headers to ALL responses, including OPTIONS and errors
    setStandardCorsHeaders(res); // Call this if handling CORS inline

    if (req.method === 'OPTIONS') {
        console.log('Responding to OPTIONS preflight request.');
        return res.status(204).end(); // 204 No Content is standard for preflight success
    }

    if (req.method !== 'POST') {
        console.log(`Method ${req.method} is not POST. Responding with 405.`);
        res.setHeader('Allow', ['POST']);
        return res.status(405).json({ error: `Method ${req.method} Not Allowed` });
    }

    // At this point, for a POST request, Vercel should have parsed the body
    // if Content-Type was application/json
    const body = req.body;
    console.log('Parsed req.body by Vercel:', JSON.stringify(body, null, 2));

    if (!body || Object.keys(body).length === 0) { // Check if body is undefined, null, or empty object
        console.error('Error: req.body is undefined, null, or empty. Cannot destructure.');
        return res.status(400).json({ error: 'Request body is missing, empty, or not valid JSON. Ensure Content-Type is application/json.' });
    }

    // Now, safely attempt to destructure
    const { firebaseJWT, field, value, docId } = body;

    if (firebaseJWT === undefined || field === undefined || value === undefined /* || docId === undefined */) {
        console.error('Error: One or more required fields (firebaseJWT, field, value) are undefined in the parsed body.', { firebaseJWT, field, value, docId });
        return res.status(400).json({ error: 'Missing required fields in body: firebaseJWT, field, value are mandatory.' });
    }

    try {
        console.log(`Processing update: field='${field}', value='${JSON.stringify(value)}', docId='${docId}', jwtPresent=${!!firebaseJWT}`);
        // --- Your actual logic ---
        // 1. Verify JWT (using firebase-admin)
        // const decodedToken = await admin.auth().verifyIdToken(firebaseJWT);
        // console.log('JWT Verified for UID:', decodedToken.uid);

        // 2. Perform Firestore update
        // if (!docId) throw new Error("docId is required for update");
        // const docRef = db.collection("yourCollectionName").doc(docId);
        // await docRef.update({ [field]: value });
        // console.log(`Firestore updated: ${docId} -> ${field} = ${value}`);
        // --- End of actual logic ---

        return res.status(200).json({ success: true, message: `Field '${field}' processed successfully.`, receivedValue: value });

    } catch (error) {
        console.error('Error during request processing:', error.name, error.message, error.code, error.stack);
        if (error.code && error.code.startsWith('auth/')) {
            return res.status(401).json({ error: 'Authentication error.', details: error.message });
        }
        return res.status(500).json({ error: 'Internal server error processing the request.', details: error.message });
    }
}

// --- OPTION B: If using vercel.json for CORS ---
// Your handler would be simpler as it wouldn't need setStandardCorsHeaders or the OPTIONS block.
// Vercel's edge would handle those.
// export default async function handler(req, res) {
//   // No explicit CORS headers or OPTIONS handling here
//   console.log(`--- New Request (vercel.json CORS): ${req.method} ${req.url} ---`);
//   // ... rest of the logic starting from if (req.method !== 'POST') ...
// }