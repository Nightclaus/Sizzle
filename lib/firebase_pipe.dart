import 'dart:convert';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

final http.Client client = kIsWeb ? BrowserClient() : http.Client();


String baseUrl = dotenv.env['API_URL'] ?? '';

class FirestorePipe {
  final String jwt;
  const FirestorePipe({required this.jwt});

  Future<String> testFirestoreFlow() async {
    final userJwt = jwt;
    final field = 'exampleField';
    final value = 'Hello from Flutter';

    try {
      // Use POST instead of PATCH for better CORS compatibility
      final updateUri = Uri.parse('$baseUrl/update-field');

      final bodyMap = {
        'firebaseJWT': userJwt,
        'field': field,
        'value': value,
      };

      final response = await client.post(
  Uri.parse('$baseUrl/update-field'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'firebaseJWT': userJwt,
    'field': field,
    'value': value,
  }),
);


      if (response.statusCode != 200) {
        debugPrint('Update failed: ${response.body}');
        return 'Update failed: ${response.body}';
      }

      // Retrieve value
      final getUri = Uri.parse('$baseUrl/get-field');

      final getResponse = await http.post(
        getUri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'firebaseJWT': userJwt,
          'field': field,
        }),
      );

      if (getResponse.statusCode != 200) {
        debugPrint('Get failed: ${getResponse.body}');
        return 'Get failed: ${getResponse.body}';
      }

      final responseData = jsonDecode(getResponse.body);
      return 'Value retrieved: ${responseData['value']}';
    } catch (e) {
      debugPrint('Error: $e');
      return 'Error: $e';
    }
  }
}
