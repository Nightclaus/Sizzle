const express = require('express');
const admin = require('firebase-admin');
require('dotenv').config(); // Load environment variables

const app = express();
app.use(express.json());

// --- Firebase Admin SDK Initialization ---
let db;
try {
    const serviceAccountBase64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
    if (!serviceAccountBase64) {
        throw new Error('FIREBASE_SERVICE_ACCOUNT_BASE64 environment variable is not set.');
    }

    const serviceAccountJson = Buffer.from(serviceAccountBase64, 'base64').toString('utf-8');
    const serviceAccount = JSON.parse(serviceAccountJson);

    let projectId = process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id;
    if (!projectId) {
        throw new Error('Firebase Project ID could not be determined. Set FIREBASE_PROJECT_ID or ensure service account has project_id.');
    }

    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId: projectId
    });

    db = admin.firestore();
    console.log("Firebase Admin SDK initialized successfully using Base64 encoded service account.");
    console.log("Project ID:", projectId);

} catch (error) {
    console.error("FATAL ERROR initializing Firebase Admin SDK:", error.message);
    process.exit(1);
}

// --- API Configuration from Environment ---
const PORT = process.env.PORT || 3000;
const collectionName = process.env.DEFAULT_COLLECTION_NAME;

if (!collectionName) {
    console.error("FATAL ERROR: DEFAULT_COLLECTION_NAME is not set in .env. API cannot function correctly.");
    process.exit(1); // Exit if critical config is missing
}


// --- API Endpoint ---
// Body expects: { docId: string, field: string, value: any }
// NOW: Creates document if docId doesn't exist, otherwise updates the field.
app.patch('/update-field', async (req, res) => {
    if (!db) {
        return res.status(503).json({ error: 'Firestore (Admin SDK) not initialized. Server configuration error.' });
    }

    try {
        const { docId, field, value } = req.body;

        if (!docId || typeof docId !== 'string' || docId.trim() === "") {
            return res.status(400).json({ error: 'Missing or invalid docId (must be a non-empty string)' });
        }
        if (!field || typeof field !== 'string' || field.trim() === "") {
            return res.status(400).json({ error: 'Missing or invalid field (must be a non-empty string)' });
        }

        const docRef = db.collection(collectionName).doc(docId);

        // We can check if it exists beforehand to provide a more specific message,
        // but set with merge:true will handle both cases.
        let actionMessage = "";
        const docSnapshot = await docRef.get();
        if (docSnapshot.exists) {
            actionMessage = `Field '${field}' in document '${docId}' (collection '${collectionName}') updated.`;
        } else {
            actionMessage = `Document '${docId}' created in collection '${collectionName}' with field '${field}'.`;
        }

        console.log(`Attempting to set/merge (via Admin SDK) document '${docId}' in collection '${collectionName}': setting field '${field}' to '${JSON.stringify(value)}'`);

        // Use set with { merge: true } to create or update
        await docRef.set({
            [field]: value // Using computed property name
        }, { merge: true });

        return res.json({
            success: true,
            message: `(Admin SDK) ${actionMessage}`,
            docId: docId,
            field: field,
            newValue: value,
            operation: docSnapshot.exists ? 'updated' : 'created'
        });

    } catch (error) {
        console.error('Error setting/merging Firestore document (Admin SDK):', error);
        let errorMessage = 'Internal server error while processing Firestore document.';
        if (error.code) { // Firebase Admin SDK errors have a 'code'
            errorMessage = `Firestore error (code: ${error.code}): ${error.message}`;
        }
        return res.status(500).json({ error: errorMessage, details: error.message });
    }
});

// --- Start Server ---
app.listen(PORT, () => {
    console.log(`Server listening on port ${PORT}`);
    console.log(`Firestore collection targeted by Admin SDK: ${collectionName}`);
    console.log(`API endpoint available at: PATCH http://localhost:${PORT}/update-field`);
    console.log(`This endpoint will now CREATE the document if docId doesn't exist, or UPDATE if it does.`);
});