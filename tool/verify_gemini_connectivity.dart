// One-off connectivity check. Run from repo root:
//   dart run tool/verify_gemini_connectivity.dart
// Does not print your API key.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:thali/core/constants/api_config.dart';

void main() async {
  final key = ApiConfig.geminiApiKey;
  final model = ApiConfig.geminiModel;

  if (key.isEmpty || key == 'YOUR_GEMINI_API_KEY_HERE') {
    print('RESULT: MISCONFIGURED (placeholder key in api_config.dart)');
    return;
  }

  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key',
  );

  try {
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': 'Reply with exactly the word: pong'}
                ],
              },
            ],
            'generationConfig': {'maxOutputTokens': 32, 'temperature': 0},
          }),
        )
        .timeout(const Duration(seconds: 30));

    final code = response.statusCode;
    if (code == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final text = body['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?;
      if (text == null || text.trim().isEmpty) {
        print('RESULT: EMPTY_RESPONSE (HTTP 200 but no model text)');
        print(
            'Hint: quota/safety/block — check JSON keys promptFeedback, blockReason in raw body.');
      } else {
        print('RESULT: OK (HTTP 200)');
        print('Model replied: ${text.trim()}');
      }
    } else {
      String msg = response.body;
      try {
        final j = jsonDecode(response.body) as Map<String, dynamic>;
        msg = j['error']?['message']?.toString() ?? msg;
      } catch (_) {}
      print('RESULT: FAILED (HTTP $code)');
      print('API message: $msg');
    }
  } on Exception catch (e) {
    print('RESULT: NETWORK_OR_CLIENT_ERROR');
    print('$e');
  }
}
