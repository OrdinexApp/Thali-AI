import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../core/constants/api_config.dart';
import '../features/history/data/models/meal_model.dart';
import 'indian_food_db.dart';

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
You are an expert Indian food nutritionist with deep knowledge of IFCT 2017 and NIN Hyderabad nutrition databases.

${detectedContext}The person had $rotiCount roti(s)/chapati(s) with this meal.

For each food item, provide precise nutritional estimates considering the cooking style and quantity specified.
Cross-reference your estimates with standard Indian food composition data.

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
      "portion": "1 serving (approx 100g)",
      "cooking_style": "Home"
    }
  ],
  "mealType": "lunch",
  "healthScore": 7,
  "healthTip": "Good protein from dal. Consider reducing rice portion for fewer carbs."
}

Important:
- Include $rotiCount roti(s) as a separate item with total calories for all $rotiCount rotis combined.
- Be realistic with typical Indian food portions for the specified cooking style.
- Include every visible item: dal, sabzi, rice, roti, chutney, pickle, raita, papad, salad, etc.
- Use IFCT 2017 / NIN calorie values for Indian food preparations.
- healthScore: integer 1-10 (10 = very healthy, balanced meal).
- healthTip: one practical tip to improve this meal's nutrition.
- cooking_style: preserve the user-confirmed cooking style for each item.
''';

    try {
      final response = await _callGemini(prompt, base64Image);
      if (response != null) {
        final parsed = _extractJson(response);
        return _parseNutritionResponse(parsed, rotiCount, mealId, imagePath);
      }
    } catch (e) {
      // Fall through
    }

    // Use local DB if detected items are available, otherwise fall back to mock
    if (detectedItems != null && detectedItems.items.isNotEmpty) {
      return _buildFromLocalDB(detectedItems, rotiCount, mealId, imagePath);
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
    final rawItems = (data['items'] as List)
        .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
        .toList();

    // Cross-validate with local DB: if Gemini returns 0 calories, fill from DB
    final items = rawItems.map((item) {
      if (item.calories > 0) return item;
      final dbEntry = IndianFoodDB.lookup(item.name);
      if (dbEntry == null) return item;
      final styled = item.cookingStyle != null
          ? IndianFoodDB.applyStyle(dbEntry, item.cookingStyle!)
          : dbEntry;
      return FoodItem(
        name: item.name,
        calories: styled.calories,
        protein: styled.protein,
        carbs: styled.carbs,
        fat: styled.fat,
        fiber: styled.fiber,
        portion: item.portion ?? styled.portion,
        cookingStyle: item.cookingStyle,
      );
    }).toList();

    double totalCalories = 0, totalProtein = 0, totalCarbs = 0;
    double totalFat = 0, totalFiber = 0;
    for (final i in items) {
      totalCalories += i.calories;
      totalProtein += i.protein;
      totalCarbs += i.carbs;
      totalFat += i.fat;
      totalFiber += i.fiber;
    }

    final healthScore = (data['healthScore'] as num?)?.toInt() ??
        _calculateHealthScore(totalCalories, totalProtein, totalCarbs,
            totalFat, totalFiber);
    final healthTip = data['healthTip'] as String?;

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
      healthScore: healthScore,
      healthTip: healthTip,
    );
  }

  int _calculateHealthScore(double cal, double pro, double carbs,
      double fat, double fiber) {
    int score = 5;
    final total = pro + carbs + fat;
    if (total <= 0) return score;

    final proteinRatio = pro / total;
    final fatRatio = fat / total;

    if (proteinRatio >= 0.2) score += 1;
    if (proteinRatio >= 0.3) score += 1;
    if (fatRatio < 0.35) score += 1;
    if (fiber >= 8) score += 1;
    if (cal <= 700) score += 1;
    if (cal > 1200) score -= 2;
    if (fatRatio > 0.45) score -= 1;

    return score.clamp(1, 10);
  }

  /// Build a full MealAnalysis from the local Indian food database
  MealAnalysis _buildFromLocalDB(
    DetectionResult detected,
    int rotiCount,
    String mealId,
    String imagePath,
  ) {
    final items = <FoodItem>[];

    for (final d in detected.items) {
      final dbEntry = IndianFoodDB.lookup(d.name);
      if (dbEntry != null) {
        final styled = IndianFoodDB.applyStyle(dbEntry, d.cookingStyle);
        // Parse quantity multiplier from estimatedQuantity (e.g. "2 pieces" → 2)
        final qtyMultiplier = _parseQuantity(d.estimatedQuantity);
        items.add(FoodItem(
          name: d.name,
          calories: styled.calories * qtyMultiplier,
          protein: styled.protein * qtyMultiplier,
          carbs: styled.carbs * qtyMultiplier,
          fat: styled.fat * qtyMultiplier,
          fiber: styled.fiber * qtyMultiplier,
          portion: d.estimatedQuantity,
          cookingStyle: d.cookingStyle,
        ));
      } else {
        items.add(FoodItem(
          name: d.name,
          calories: 150,
          protein: 5.0,
          carbs: 20.0,
          fat: 5.0,
          fiber: 2.0,
          portion: d.estimatedQuantity,
          cookingStyle: d.cookingStyle,
        ));
      }
    }

    // Ensure roti is in the list
    final hasRoti = items.any(
        (i) => i.name.toLowerCase().contains('roti') || i.name.toLowerCase().contains('chapati'));
    if (!hasRoti && rotiCount > 0) {
      final rotiBase = IndianFoodDB.lookup('roti')!;
      items.insert(0, FoodItem(
        name: 'Roti',
        calories: rotiBase.calories * rotiCount,
        protein: rotiBase.protein * rotiCount,
        carbs: rotiBase.carbs * rotiCount,
        fat: rotiBase.fat * rotiCount,
        fiber: rotiBase.fiber * rotiCount,
        portion: '$rotiCount piece(s)',
        cookingStyle: 'Home',
      ));
    }

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
      mealType: 'meal',
      healthScore: _calculateHealthScore(
          totalCalories, totalProtein, totalCarbs, totalFat, totalFiber),
      healthTip: 'Values calculated from standard Indian food database (IFCT 2017).',
    );
  }

  double _parseQuantity(String qty) {
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(qty);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 1.0;
    }
    return 1.0;
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
        cookingStyle: 'Home',
      ),
      FoodItem(
        name: 'Dal Tadka',
        calories: 180,
        protein: 9.0,
        carbs: 24.0,
        fat: 6.0,
        fiber: 4.5,
        portion: '1 bowl (150ml)',
        cookingStyle: 'Home',
      ),
      FoodItem(
        name: 'Aloo Gobi',
        calories: 160,
        protein: 4.0,
        carbs: 22.0,
        fat: 7.0,
        fiber: 3.5,
        portion: '1 serving (120g)',
        cookingStyle: 'Home',
      ),
      FoodItem(
        name: 'Steamed Rice',
        calories: 200,
        protein: 4.0,
        carbs: 44.0,
        fat: 0.5,
        fiber: 0.6,
        portion: '1 cup (150g)',
        cookingStyle: 'Home',
      ),
      FoodItem(
        name: 'Raita',
        calories: 65,
        protein: 3.0,
        carbs: 5.0,
        fat: 3.5,
        fiber: 0.2,
        portion: '1 small bowl (80ml)',
        cookingStyle: 'Home',
      ),
      FoodItem(
        name: 'Pickle',
        calories: 30,
        protein: 0.5,
        carbs: 2.0,
        fat: 2.5,
        fiber: 0.5,
        portion: '1 tbsp',
        cookingStyle: 'Home',
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
      healthScore: _calculateHealthScore(
          totalCalories, totalProtein, totalCarbs, totalFat, totalFiber),
      healthTip: 'Good protein from dal. Consider adding a green salad for more fiber.',
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
