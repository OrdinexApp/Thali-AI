import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/api_config.dart';
import '../features/history/data/models/meal_model.dart';

class GeminiService {
  static String get _apiKey => ApiConfig.geminiApiKey;
  static String get _baseUrl => ApiConfig.geminiBaseUrl;

  /// Step 1: Detect food items from the photo using the exact prompt
  Future<DetectionResult> detectFoodItems(String imagePath) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(imageBytes);

    const prompt = '''
You are an expert Indian food nutritionist. Analyze this photo of a meal. Detect all major items on the plate.

Return the result in this exact JSON format only:

{
  "items": [
    {"name": "Paneer Butter Masala", "estimated_quantity": "1 bowl"},
    {"name": "Dal Tadka", "estimated_quantity": "1 bowl"},
    {"name": "Rice", "estimated_quantity": "1 cup"},
    {"name": "Roti", "estimated_quantity": "2 pieces"}
  ],
  "suggested_labels": ["Paneer Butter Masala", "Dal Tadka", "Rice", "Roti"]
}

Be accurate with Indian dishes.''';

    try {
      final response = await _callGemini(prompt, base64Image);
      if (response != null) {
        final parsed = _extractJson(response);
        final items = (parsed['items'] as List?)
                ?.map((e) => DetectedItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        final labels = (parsed['suggested_labels'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            items.map((e) => e.name).toList();

        return DetectionResult(items: items, suggestedLabels: labels);
      }
    } catch (e) {
      // Fall through to mock
    }

    return _getMockDetection();
  }

  /// Step 2: Get full nutritional breakdown including roti count
  Future<MealAnalysis> analyzeThaliImage({
    required String imagePath,
    required int rotiCount,
    required String mealId,
    DetectionResult? detectedItems,
  }) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(imageBytes);

    String detectedContext = '';
    if (detectedItems != null && detectedItems.items.isNotEmpty) {
      final itemsList = detectedItems.items
          .map((i) =>
              '- ${i.name} (${i.estimatedQuantity}, ${i.cookingStyle} style)')
          .join('\n');
      detectedContext = '''
Previously detected items in this meal (user-confirmed):
$itemsList

Adjust calorie estimates based on the cooking style:
- "Home" = normal homemade with moderate oil/ghee
- "Restaurant" = richer, more oil/butter/cream
- "Less Oil" = lighter preparation, less fat
- "Diet" = minimal oil, boiled/steamed where possible

''';
    }

    final prompt = '''
You are an expert Indian food nutritionist. Analyze this photo of an Indian meal.

${detectedContext}The person had $rotiCount roti(s)/chapati(s) with this meal.

For each food item visible, provide detailed nutritional estimates per serving.

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

Important:
- Include $rotiCount roti(s) as a separate item with total calories for all $rotiCount rotis combined.
- Be realistic with typical Indian restaurant/homemade portions.
- Include every visible item: dal, sabzi, rice, roti, chutney, pickle, raita, papad, salad, etc.
- Use accurate calorie values for Indian food preparations.
''';

    try {
      final response = await _callGemini(prompt, base64Image);
      if (response != null) {
        final parsed = _extractJson(response);
        return _parseNutritionResponse(parsed, rotiCount, mealId, imagePath);
      }
    } catch (e) {
      // Fall through to mock
    }

    return _getMockAnalysis(rotiCount, mealId, imagePath);
  }

  Future<String?> _callGemini(String prompt, String base64Image) async {
    final response = await http
        .post(
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
              'maxOutputTokens': 4096,
            }
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text']
          as String?;
    }
    return null;
  }

  Map<String, dynamic> _extractJson(String text) {
    var cleaned = text.trim();
    // Strip markdown code fences if present
    cleaned = cleaned.replaceAll(RegExp(r'```json\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\s*'), '');
    cleaned = cleaned.trim();

    // Find the first { and last } to extract JSON object
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      cleaned = cleaned.substring(start, end + 1);
    }

    return jsonDecode(cleaned) as Map<String, dynamic>;
  }

  MealAnalysis _parseNutritionResponse(
    Map<String, dynamic> data,
    int rotiCount,
    String mealId,
    String imagePath,
  ) {
    final items = (data['items'] as List)
        .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
        .toList();

    double totalCalories = 0, totalProtein = 0, totalCarbs = 0;
    double totalFat = 0, totalFiber = 0;
    for (final i in items) {
      totalCalories += i.calories;
      totalProtein += i.protein;
      totalCarbs += i.carbs;
      totalFat += i.fat;
      totalFiber += i.fiber;
    }

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

  DetectionResult _getMockDetection() {
    return DetectionResult(
      items: [
        DetectedItem(name: 'Dal Tadka', estimatedQuantity: '1 bowl'),
        DetectedItem(name: 'Aloo Gobi', estimatedQuantity: '1 serving'),
        DetectedItem(name: 'Steamed Rice', estimatedQuantity: '1 cup'),
        DetectedItem(name: 'Roti', estimatedQuantity: '2 pieces'),
        DetectedItem(name: 'Raita', estimatedQuantity: '1 small bowl'),
        DetectedItem(name: 'Pickle', estimatedQuantity: '1 tbsp'),
      ],
      suggestedLabels: [
        'Dal Tadka',
        'Aloo Gobi',
        'Steamed Rice',
        'Roti',
        'Raita',
        'Pickle',
      ],
    );
  }

  MealAnalysis _getMockAnalysis(
      int rotiCount, String mealId, String imagePath) {
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

    double totalCalories = 0, totalProtein = 0, totalCarbs = 0;
    double totalFat = 0, totalFiber = 0;
    for (final i in items) {
      totalCalories += i.calories;
      totalProtein += i.protein;
      totalCarbs += i.carbs;
      totalFat += i.fat;
      totalFiber += i.fiber;
    }

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

/// Result from the initial food detection step
class DetectedItem {
  final String name;
  final String estimatedQuantity;
  final String cookingStyle;
  final bool confirmed;

  DetectedItem({
    required this.name,
    required this.estimatedQuantity,
    this.cookingStyle = 'Home',
    this.confirmed = false,
  });

  DetectedItem copyWith({
    String? name,
    String? estimatedQuantity,
    String? cookingStyle,
    bool? confirmed,
  }) {
    return DetectedItem(
      name: name ?? this.name,
      estimatedQuantity: estimatedQuantity ?? this.estimatedQuantity,
      cookingStyle: cookingStyle ?? this.cookingStyle,
      confirmed: confirmed ?? this.confirmed,
    );
  }

  factory DetectedItem.fromJson(Map<String, dynamic> json) => DetectedItem(
        name: json['name'] as String? ?? 'Unknown',
        estimatedQuantity: json['estimated_quantity'] as String? ?? '1 serving',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'estimated_quantity': estimatedQuantity,
        'cooking_style': cookingStyle,
      };
}

class DetectionResult {
  final List<DetectedItem> items;
  final List<String> suggestedLabels;

  DetectionResult({required this.items, required this.suggestedLabels});

  DetectionResult copyWithItem(int index, DetectedItem item) {
    final newItems = List<DetectedItem>.from(items);
    newItems[index] = item;
    return DetectionResult(items: newItems, suggestedLabels: suggestedLabels);
  }
}
