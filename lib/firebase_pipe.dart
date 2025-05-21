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

  late Map<String, String> headers;
  late Uri updateUri;
  late Uri getUri;

  FirestorePipe({required this.jwt}) {
    updateUri = Uri.parse('$baseUrl/update-field');
    getUri = Uri.parse('$baseUrl/get-field');
    headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<bool> updateValue(String field, String value) async {
    final updateBody = jsonEncode({
      'firebaseJWT': jwt,
      'field': field,
      'value': value,
      'docId': 'NONE'
    });
    try {
      debugPrint('[o] Sending update request to $updateUri');

      final response = await client.post(
        updateUri,
        headers: headers,
        body: updateBody,
      );

      if (response.statusCode != 200) {
        debugPrint('[x] Update failed: ${response.statusCode} - ${response.body}');
        debugPrint('Update failed: ${response.body}');
        return false;
      } else {
        debugPrint('[o] Update successful');
        return true;
      }
    } catch (e) {
      debugPrint('Error occurred: $e');
      return false;
    }
  }

  Future<dynamic> getValue(String field) async {
    final getBody = jsonEncode({
      'firebaseJWT': jwt,
      'field': field,
    });
    try{
      debugPrint('Sending get request to $getUri');
      final getResponse = await client.post(
        getUri,
        headers: headers,
        body: getBody,
      );

      if (getResponse.statusCode != 200) {
        debugPrint('[x] Get failed: ${getResponse.statusCode} - ${getResponse.body}');
        return 'Get failed: ${getResponse.body}';
      }

      final responseData = jsonDecode(getResponse.body);
      final retrievedValue = responseData['value'] ?? '[null]';
      debugPrint('[o] Value retrieved: $retrievedValue');

      return 'Value retrieved: $retrievedValue';
    } catch (e) {
      debugPrint('Error occurred: $e');
      return 'Error: $e';
    }
  }

  Future<dynamic> testFirestoreFlow() {
    const testField = "Testfield";
    const testValue = "test_value";
    updateValue(testField, testValue);
    return getValue(testField);
  }
}
