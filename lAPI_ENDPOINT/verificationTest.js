require('dotenv').config();
const admin = require('firebase-admin');

const base64ServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;

if (!base64ServiceAccount) {
  throw new Error('FIREBASE_SERVICE_ACCOUNT_BASE64 is not defined in .env file');
}

const serviceAccount = JSON.parse(Buffer.from(base64ServiceAccount, 'base64').toString('utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Example token verification function
async function verifyToken(idToken) {
  try {
    const decodedToken = await admin.auth().verifyIdToken(idToken);
    console.log('Token valid. UID:', decodedToken.uid);
    return decodedToken;
  } catch (error) {
    console.error('Token verification failed:', error);
    throw error;
  }
}

// Example usage:
const idToken = 'eyJhbGciOiJSUzI1NiIsImtpZCI6IjU5MWYxNWRlZTg0OTUzNjZjOTgyZTA1MTMzYmNhOGYyNDg5ZWFjNzIiLCJ0eXAiOiJKV1QifQ.eyJuYW1lIjoiU3RlcGhlbiBaaG9uZyIsInBpY3R1cmUiOiJodHRwczovL2xoMy5nb29nbGV1c2VyY29udGVudC5jb20vYS9BQ2c4b2NMbzhwUDgzRk9PT3dUM0lqVm85QVdMOTJ0QjBWUXdud0tHblU0WEhKbnpYVDhlMm9LNj1zOTYtYyIsImlzcyI6Imh0dHBzOi8vc2VjdXJldG9rZW4uZ29vZ2xlLmNvbS9zaXp6bGUtYTg4OGUiLCJhdWQiOiJzaXp6bGUtYTg4OGUiLCJhdXRoX3RpbWUiOjE3NDczNjM1ODYsInVzZXJfaWQiOiJpVzN5SndKQjJCUmdPQVlLOWZUOHFsU0owcWkyIiwic3ViIjoiaVczeUp3SkIyQlJnT0FZSzlmVDhxbFNKMHFpMiIsImlhdCI6MTc0NzM2MzU4NiwiZXhwIjoxNzQ3MzY3MTg2LCJlbWFpbCI6Inpob25nX3N0QHN0dWRlbnQua2luZ3MuZWR1LmF1IiwiZW1haWxfdmVyaWZpZWQiOnRydWUsImZpcmViYXNlIjp7ImlkZW50aXRpZXMiOnsiZ29vZ2xlLmNvbSI6WyIxMDU2NDgxNTU0ODQwMjA4MjA0NjYiXSwiZW1haWwiOlsiemhvbmdfc3RAc3R1ZGVudC5raW5ncy5lZHUuYXUiXX0sInNpZ25faW5fcHJvdmlkZXIiOiJnb29nbGUuY29tIn19.xJ3YNBmMCJSnBnZtLN-EQeQ-n_gVghBC7fDm6hcWrekckZeE4pVBQFTl36XcA4h0H9B9LVcTVKNt8d1fxENnTW45qYLdmQrf3QFU7Py9hpBu6CQAPdV4zGn6ZrYeQwlFszZgTHBZL5mIm-mMiZjzIg2G-eE0Iiuhfsv3y-hMlLCO6iWmLr_uJzN7yW2UGyhzbxB7qDXx0dnAO--BHh4p1CvuFX7uTQfSonc5MYqbelpotbBmYJTllodr6BKLh25LzvYzi9QQPkbmpSY8cY7uga2BeTyFSUgPba6XY2WluZWj6qZpPxFE4atWvV7FiaUxKVtu_WS2SVq0xx05obhc2g';
verifyToken(idToken);