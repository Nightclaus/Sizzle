import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

String baseUrl = dotenv.env['API_URL'] ?? '';

class FirestorePipe {
  final String jwt;
  const FirestorePipe({required this.jwt});

  Future<String> testFirestoreFlow() async {
    final userJwt = jwt;
    final field = 'exampleField';
    final value = 'Hello from Flutter';

    try {
      // Step 1: Update field (using POST to match backend)
      final updateResponse = await http.post(
        Uri.parse('$baseUrl/update-field'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebaseJWT': userJwt,
          'field': field,
          'value': value,
        }),
      );

      if (updateResponse.statusCode != 200) {
        return 'Update failed: ${updateResponse.body}';
      }

      // Step 2: Retrieve field (assuming get-field endpoint expects POST with firebaseJWT + field)
      final getResponse = await http.post(
        Uri.parse('$baseUrl/get-field'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebaseJWT': userJwt,
          'field': field,
        }),
      );

      if (getResponse.statusCode != 200) {
        return 'Get failed: ${getResponse.body}';
      }

      final responseData = jsonDecode(getResponse.body);
      return 'Value retrieved: ${responseData['value']}';
    } catch (e) {
      return 'Error: $e';
    }
  }
}