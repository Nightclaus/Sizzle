// /api/_utils/firebaseAdmin.js
import admin from 'firebase-admin';

// Ensure Firebase Admin SDK is initialized only once
if (!admin.apps.length) {
  try {
    const serviceAccountBase64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
    if (!serviceAccountBase64) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_BASE64 environment variable is not set.');
    }

    const serviceAccountJsonString = Buffer.from(serviceAccountBase64, 'base64').toString('utf-8');
    const serviceAccount = JSON.parse(serviceAccountJsonString);

    const projectId = process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id;
    if (!projectId) {
      throw new Error('Firebase Project ID could not be determined.');
    }

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: projectId,
    });
    console.log('Firebase Admin SDK initialized successfully (shared).');
    console.log('Project ID (shared):', projectId);
  } catch (error) {
    console.error('FATAL ERROR initializing Firebase Admin SDK (shared):', error.message);
    // Depending on your error handling strategy, you might throw this or handle it
    // For a serverless function, if this fails, subsequent calls will likely fail anyway.
  }
}

const db = admin.firestore();
const auth = admin.auth();

async function decodeFirebaseToken(idTokenString) {
  if (!idTokenString) {
    console.warn('decodeFirebaseToken called with no token.');
    return null;
  }
  try {
    const decodedToken = await auth.verifyIdToken(idTokenString);
    // console.log('Token successfully verified. UID:', decodedToken.uid);
    return decodedToken; // Returns the full decoded token object
  } catch (error) {
    console.error('Firebase token verification failed:', error.code, error.message);
    // Log specific known error codes for better debugging
    if (error.code === 'auth/id-token-expired') {
      console.error('Firebase ID token has expired.');
    } else if (error.code === 'auth/argument-error') {
      console.error('Firebase ID token is malformed or an empty string.');
    }
    return null;
  }
}

const defaultCollectionName = process.env.DEFAULT_COLLECTION_NAME;
if (!defaultCollectionName) {
    console.error("CRITICAL: DEFAULT_COLLECTION_NAME is not set in environment variables.");
    // This won't stop the serverless function from trying to run, but operations will fail.
    // Consider a more robust way to handle this if the app can't function without it.
}


export { db, auth, decodeFirebaseToken, defaultCollectionName, admin };