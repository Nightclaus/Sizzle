export default async function handler(req, res) {
  // ✅ CORS headers
  res.setHeader('Access-Control-Allow-Credentials', 'true');
  res.setHeader('Access-Control-Allow-Origin', '*'); // Use '*' or your Flutter Web domain
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  // ✅ Handle preflight OPTIONS request
  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  // ✅ Your actual logic here
  const { firebaseJWT, field, value } = req.body;

  if (!firebaseJWT || !field || !value) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  // Simulate a database update or pass to Firestore, etc.
  console.log(`Updating ${field} = ${value} for JWT: ${firebaseJWT}`);

  return res.status(200).json({ message: 'Field updated' });
}
