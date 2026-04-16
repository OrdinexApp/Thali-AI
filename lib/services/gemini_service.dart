import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../features/history/data/models/meal_model.dart';

class GeminiService {
  // Replace with your actual API key
  static const String _apiKey = 'YOUR_GEMINI_API_KEY';
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  Future<MealAnalysis> analyzeThaliImage({
    required String imagePath,
    required int rotiCount,
    required String mealId,
  }) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(imageBytes);

    final prompt = '''
Analyze this Indian thali/food image and provide a detailed nutritional breakdown.

The person had $rotiCount roti(s)/chapati(s) with this meal.

Please identify each food item visible in the thali and provide estimated nutritional information.

Return ONLY a valid JSON object (no markdown, no code blocks) in this exact format:
{
  "items": [
    {
      "name": "Food Item Name",
      "calories": 150,
      "protein": 5.0,
      "carbs": 20.0,
      "fat": 3.0,
      "fiber": 2.0,
      "portion": "1 serving (approx 100g)"
    }
  ],
  "mealType": "lunch"
}

Include the $rotiCount roti(s) as a separate item in the items list.
Be realistic with Indian food portions and calorie estimates.
Include all visible items: dal, sabzi, rice, roti, chutney, pickle, raita, etc.
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            'maxOutputTokens': 2048,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'] as String;

        final cleanedJson = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        final parsed = jsonDecode(cleanedJson) as Map<String, dynamic>;

        return _parseResponse(parsed, rotiCount, mealId, imagePath);
      } else {
        return _getMockAnalysis(rotiCount, mealId, imagePath);
      }
    } catch (e) {
      return _getMockAnalysis(rotiCount, mealId, imagePath);
    }
  }

  MealAnalysis _parseResponse(
    Map<String, dynamic> data,
    int rotiCount,
    String mealId,
    String imagePath,
  ) {
    final items = (data['items'] as List)
        .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
        .toList();

    final totalCalories = items.fold(0.0, (sum, i) => sum + i.calories);
    final totalProtein = items.fold(0.0, (sum, i) => sum + i.protein);
    final totalCarbs = items.fold(0.0, (sum, i) => sum + i.carbs);
    final totalFat = items.fold(0.0, (sum, i) => sum + i.fat);
    final totalFiber = items.fold(0.0, (sum, i) => sum + i.fiber);

    return MealAnalysis(
      id: mealId,
      items: items,
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFat: totalFat,
      totalFiber: totalFiber,
      rotiCount: rotiCount,
      imagePath: imagePath,
      mealType: data['mealType'] as String? ?? 'meal',
    );
  }

  MealAnalysis _getMockAnalysis(int rotiCount, String mealId, String imagePath) {
    final items = [
      FoodItem(
        name: 'Roti',
        calories: 120.0 * rotiCount,
        protein: 3.5 * rotiCount,
        carbs: 20.0 * rotiCount,
        fat: 3.5 * rotiCount,
        fiber: 1.2 * rotiCount,
        portion: '$rotiCount piece(s)',
      ),
      FoodItem(
        name: 'Dal Tadka',
        calories: 180,
        protein: 9.0,
        carbs: 24.0,
        fat: 6.0,
        fiber: 4.5,
        portion: '1 bowl (150ml)',
      ),
      FoodItem(
        name: 'Aloo Gobi',
        calories: 160,
        protein: 4.0,
        carbs: 22.0,
        fat: 7.0,
        fiber: 3.5,
        portion: '1 serving (120g)',
      ),
      FoodItem(
        name: 'Steamed Rice',
        calories: 200,
        protein: 4.0,
        carbs: 44.0,
        fat: 0.5,
        fiber: 0.6,
        portion: '1 cup (150g)',
      ),
      FoodItem(
        name: 'Raita',
        calories: 65,
        protein: 3.0,
        carbs: 5.0,
        fat: 3.5,
        fiber: 0.2,
        portion: '1 small bowl (80ml)',
      ),
      FoodItem(
        name: 'Pickle',
        calories: 30,
        protein: 0.5,
        carbs: 2.0,
        fat: 2.5,
        fiber: 0.5,
        portion: '1 tbsp',
      ),
    ];

    final totalCalories = items.fold(0.0, (sum, i) => sum + i.calories);
    final totalProtein = items.fold(0.0, (sum, i) => sum + i.protein);
    final totalCarbs = items.fold(0.0, (sum, i) => sum + i.carbs);
    final totalFat = items.fold(0.0, (sum, i) => sum + i.fat);
    final totalFiber = items.fold(0.0, (sum, i) => sum + i.fiber);

    return MealAnalysis(
      id: mealId,
      items: items,
      totalCalories: totalCalories,
      totalProtein: totalProtein,
      totalCarbs: totalCarbs,
      totalFat: totalFat,
      totalFiber: totalFiber,
      rotiCount: rotiCount,
      imagePath: imagePath,
      mealType: 'lunch',
    );
  }
}
