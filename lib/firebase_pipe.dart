import 'dart:convert';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/browser_client.dart';

// Use BrowserClient for Flutter Web
final http.Client client = kIsWeb ? BrowserClient() : http.Client();

String baseUrl = dotenv.env['API_URL'] ?? '';

class FirestorePipe {
  final String jwt;
  const FirestorePipe({required this.jwt});

  Future<String> testFirestoreFlow() async {
    final userJwt = jwt;
    final field = 'exampleField';
    final value = 'Hello from Flutter';

    final updateUri = Uri.parse('$baseUrl/update-field');
    final getUri = Uri.parse('$baseUrl/get-field');

    final headers = {
      'Content-Type': 'application/json',
      // You can add more headers here if Vercel expects CORS-specific ones
      'Accept': 'application/json',
    };

    final updateBody = jsonEncode({
      'firebaseJWT': userJwt,
      'field': field,
      'value': value,
    });

    final getBody = jsonEncode({
      'firebaseJWT': userJwt,
      'field': field,
    });

    try {
      // ✅ CORS-safe POST instead of PATCH
      debugPrint('Sending update request to $updateUri');
      debugPrint('Headers: $headers');
      debugPrint('Body: $updateBody');

      final response = await client.post(
        updateUri,
        headers: headers,
        body: updateBody,
      );

      if (response.statusCode != 200) {
        debugPrint('❌ Update failed: ${response.statusCode} - ${response.body}');
        return 'Update failed: ${response.body}';
      }

      debugPrint('✅ Update successful');

      // ✅ Use same client for consistent behavior
      debugPrint('Sending get request to $getUri');
      debugPrint('Headers: $headers');
      debugPrint('Body: $getBody');

      final getResponse = await client.post(
        getUri,
        headers: headers,
        body: getBody,
      );

      if (getResponse.statusCode != 200) {
        debugPrint('❌ Get failed: ${getResponse.statusCode} - ${getResponse.body}');
        return 'Get failed: ${getResponse.body}';
      }

      final responseData = jsonDecode(getResponse.body);
      final retrievedValue = responseData['value'] ?? '[null]';
      debugPrint('✅ Value retrieved: $retrievedValue');

      return 'Value retrieved: $retrievedValue';
    } catch (e) {
      debugPrint('❗ Error occurred: $e');
      return 'Error: $e';
    }
  }
}
