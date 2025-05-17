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
      final updateUri = Uri.parse('$baseUrl/update-field');

      final updateBody = {
        'firebaseJWT': userJwt,
        'field': field,
        'value': value,
      };

      debugPrint('➡️ Sending to $updateUri');
      debugPrint('📦 Body: ${jsonEncode(updateBody)}');

      final updateResponse = await client.post(
        updateUri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateBody),
      );

      debugPrint('📥 Update status: ${updateResponse.statusCode}');
      debugPrint('📥 Update response: ${updateResponse.body}');

      if (updateResponse.statusCode != 200) {
        return 'Update failed: ${updateResponse.body}';
      }

      // Retrieve value
      final getUri = Uri.parse('$baseUrl/get-field');
      final getBody = {
        'firebaseJWT': userJwt,
        'field': field,
      };

      debugPrint('➡️ Getting from $getUri');
      debugPrint('📦 Get body: ${jsonEncode(getBody)}');

      final getResponse = await client.post(
        getUri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(getBody),
      );

      debugPrint('📥 Get status: ${getResponse.statusCode}');
      debugPrint('📥 Get response: ${getResponse.body}');

      if (getResponse.statusCode != 200) {
        return 'Get failed: ${getResponse.body}';
      }

      final responseData = jsonDecode(getResponse.body);
      return '✅ Value retrieved: ${responseData['value']}';
    } catch (e) {
      debugPrint('❌ Error: $e');
      return 'Error: $e';
    }
  }
}
