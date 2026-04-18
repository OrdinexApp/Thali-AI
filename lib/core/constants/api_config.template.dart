/// Copy this file as api_config.dart and fill in your API key.
/// DO NOT commit api_config.dart — it is gitignored.
class ApiConfig {
  ApiConfig._();

  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';

  /// Prefer a current model; older IDs may return 404 for new API keys.
  static const String geminiModel = 'gemini-2.5-flash';

  static String get geminiBaseUrl =>
      'https://generativelanguage.googleapis.com/v1beta/models/$geminiModel:generateContent';
}
