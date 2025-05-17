import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> sendToFirestore(String jwt) async {
  final response = await http.post(
    Uri.parse("https://sizzle-kmwy.vercel.app/api/update-field"),
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'firebaseJWT': jwt,
      'field': 'testField',
      'value': 'Hello from Flutter',
    }),
  );

  print('Status code: ${response.statusCode}');
  print('Response body: ${response.body}');
  return response.statusCode.toString();
}
