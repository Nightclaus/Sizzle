// /api/_utils/firebaseAdmin.js
import admin from 'firebase-admin';

if (!admin.apps.length) {
  try {
    const serviceAccountBase64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
    if (!serviceAccountBase64) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT_BASE64 environment variable is not set.');
    }
    const serviceAccountJsonString = Buffer.from(serviceAccountBase64, 'base64').toString('utf-8');
    const serviceAccount = JSON.parse(serviceAccountJsonString);
    const projectId = process.env.FIREBASE_PROJECT_ID || serviceAccount.project_id;
    if (!projectId) throw new Error('Firebase Project ID could not be determined.');

    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: projectId,
    });
    console.log('Firebase Admin SDK initialized successfully (shared).');
  } catch (error) {
    console.error('FATAL ERROR initializing Firebase Admin SDK (shared):', error.message);
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
    return decodedToken;
  } catch (error) {
    console.error('Firebase token verification failed:', error.code, error.message);
    return null;
  }
}

const defaultCollectionName = process.env.DEFAULT_COLLECTION_NAME;
if (!defaultCollectionName) {
    console.error("CRITICAL: DEFAULT_COLLECTION_NAME is not set in environment variables for Firebase Admin.");
}

export { db, auth, decodeFirebaseToken, defaultCollectionName, admin };