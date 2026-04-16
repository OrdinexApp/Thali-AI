import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_config.dart';
import '../features/history/data/models/meal_model.dart';
import 'indian_food_db.dart';

class GeminiApiException implements Exception {
  final int statusCode;
  final String message;
  GeminiApiException(this.statusCode, this.message);

  @override
  String toString() => 'GeminiApiException($statusCode): $message';

  bool get isQuotaExhausted => statusCode == 429;
  bool get isNotFound => statusCode == 404;
  bool get isAuthError => statusCode == 401 || statusCode == 403;
}

class GeminiService {
  static String get _apiKey => ApiConfig.geminiApiKey;

  static const _models = [
    'gemini-2.5-flash-lite',
    'gemini-3-flash-preview',
  ];

  String _buildUrl(String model) =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey';

  /// Step 1: Detect food items from the photo
  Future<DetectionResult> detectFoodItems(String imagePath) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(imageBytes);

    const prompt = '''
You are an expert Indian food nutritionist. Carefully analyze this photo and detect EVERY distinct food item visible.

For each item, estimate its CENTER position in the image as x,y fractions where:
- x: 0.0 = left edge, 0.5 = center, 1.0 = right edge
- y: 0.0 = top edge, 0.5 = center, 1.0 = bottom edge

Look at each bowl, plate section, and side item carefully. Position must point to the CENTER of that specific item.

Return ONLY this exact JSON format:

{
  "items": [
    {"name": "Paneer Butter Masala", "estimated_quantity": "1 bowl", "x": 0.7, "y": 0.3},
    {"name": "Dal Tadka", "estimated_quantity": "1 bowl", "x": 0.3, "y": 0.2},
    {"name": "Rice", "estimated_quantity": "1 cup", "x": 0.5, "y": 0.5},
    {"name": "Roti", "estimated_quantity": "2 pieces", "x": 0.2, "y": 0.7}
  ],
  "suggested_labels": ["Paneer Butter Masala", "Dal Tadka", "Rice", "Roti"]
}

Rules:
- Detect EVERY distinct food item. Don't miss anything — check bowls, sides, bread, rice, pickles, chutneys, papad, salad, etc.
- NEVER duplicate items. If there are 3 rotis, list once as "Roti" with quantity "3 pieces".
- Use specific Indian dish names (e.g. "Bhindi Masala" not "Vegetable Curry").
- x,y MUST accurately point to the CENTER of each food item in the photo. Be precise.
- Return ONLY valid JSON, no markdown, no extra text.''';

    final response = await _callGeminiWithRetry(prompt, base64Image);
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

      return DetectionResult(
        items: items,
        suggestedLabels: labels,
        isFromApi: true,
      );
    }

    // This means all retries and models failed
    throw GeminiApiException(0, 'All API attempts failed. Using offline detection is available.');
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
      final response = await _callGeminiWithRetry(prompt, base64Image);
      if (response != null) {
        final parsed = _extractJson(response);
        return _parseNutritionResponse(parsed, rotiCount, mealId, imagePath);
      }
    } catch (e) {
      debugPrint('[Gemini] Step 2 API error: $e');
    }

    if (detectedItems != null && detectedItems.items.isNotEmpty) {
      return _buildFromLocalDB(detectedItems, rotiCount, mealId, imagePath);
    }
    return _getMockAnalysis(rotiCount, mealId, imagePath);
  }

  /// Call Gemini with retry + model fallback
  Future<String?> _callGeminiWithRetry(String prompt, String base64Image) async {
    for (final model in _models) {
      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          final result = await _callGemini(prompt, base64Image, model);
          if (result != null) return result;
        } on GeminiApiException catch (e) {
          debugPrint('[Gemini] $model attempt ${attempt + 1}: ${e.message}');

          if (e.isNotFound || e.isAuthError) {
            break; // No point retrying this model
          }

          if ((e.isQuotaExhausted || e.statusCode == 503) && attempt < 2) {
            final waitSecs = _parseRetryDelay(e.message);
            debugPrint('[Gemini] Rate limited / unavailable, waiting ${waitSecs}s before retry...');
            await Future.delayed(Duration(seconds: waitSecs));
            continue;
          }

          break; // Other errors, try next model
        } catch (e) {
          debugPrint('[Gemini] $model attempt ${attempt + 1} unexpected: $e');
          break;
        }
      }
    }
    return null;
  }

  int _parseRetryDelay(String message) {
    final match = RegExp(r'retry in (\d+)').firstMatch(message.toLowerCase());
    if (match != null) {
      final secs = int.tryParse(match.group(1)!) ?? 5;
      return secs.clamp(2, 30);
    }
    return 5;
  }

  Future<String?> _callGemini(String prompt, String base64Image, String model) async {
    debugPrint('[Gemini] Calling model: $model');

    final response = await http
        .post(
          Uri.parse(_buildUrl(model)),
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
        .timeout(const Duration(seconds: 45));

    debugPrint('[Gemini] Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      debugPrint('[Gemini] Success! Response length: ${text?.length ?? 0}');
      return text;
    }

    // Parse error details
    String errorMsg = 'HTTP ${response.statusCode}';
    try {
      final errorData = jsonDecode(response.body);
      errorMsg = errorData['error']?['message'] as String? ?? errorMsg;
    } catch (_) {}

    debugPrint('[Gemini] Error: $errorMsg');
    throw GeminiApiException(response.statusCode, errorMsg);
  }

  Map<String, dynamic> _extractJson(String text) {
    var cleaned = text.trim();
    cleaned = cleaned.replaceAll(RegExp(r'```json\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'```\s*'), '');
    cleaned = cleaned.trim();

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
      healthTip: 'Values from Indian food database (IFCT 2017). For AI-powered analysis, check your Gemini API quota.',
    );
  }

  double _parseQuantity(String qty) {
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(qty);
    if (match != null) {
      return double.tryParse(match.group(1)!) ?? 1.0;
    }
    return 1.0;
  }

  MealAnalysis _getMockAnalysis(
      int rotiCount, String mealId, String imagePath) {
    final items = [
      FoodItem(name: 'Roti', calories: 120.0 * rotiCount, protein: 3.5 * rotiCount, carbs: 20.0 * rotiCount, fat: 3.5 * rotiCount, fiber: 1.2 * rotiCount, portion: '$rotiCount piece(s)', cookingStyle: 'Home'),
      FoodItem(name: 'Dal Tadka', calories: 180, protein: 9.0, carbs: 24.0, fat: 6.0, fiber: 4.5, portion: '1 bowl (150ml)', cookingStyle: 'Home'),
      FoodItem(name: 'Mixed Veg Curry', calories: 140, protein: 4.0, carbs: 16.0, fat: 7.0, fiber: 4.0, portion: '1 serving (120g)', cookingStyle: 'Home'),
      FoodItem(name: 'Steamed Rice', calories: 200, protein: 4.0, carbs: 44.0, fat: 0.5, fiber: 0.6, portion: '1 cup (150g)', cookingStyle: 'Home'),
      FoodItem(name: 'Raita', calories: 65, protein: 3.0, carbs: 5.0, fat: 3.5, fiber: 0.2, portion: '1 small bowl (80ml)', cookingStyle: 'Home'),
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
      healthScore: _calculateHealthScore(totalCalories, totalProtein, totalCarbs, totalFat, totalFiber),
      healthTip: 'Offline fallback values. Check your Gemini API quota for AI-powered analysis.',
    );
  }
}

class DetectedItem {
  final String name;
  final String estimatedQuantity;
  final String cookingStyle;
  final bool confirmed;
  final double x; // 0.0 (left) to 1.0 (right) position in image
  final double y; // 0.0 (top) to 1.0 (bottom) position in image

  DetectedItem({
    required this.name,
    required this.estimatedQuantity,
    this.cookingStyle = 'Home',
    this.confirmed = false,
    this.x = 0.5,
    this.y = 0.5,
  });

  DetectedItem copyWith({
    String? name,
    String? estimatedQuantity,
    String? cookingStyle,
    bool? confirmed,
    double? x,
    double? y,
  }) {
    return DetectedItem(
      name: name ?? this.name,
      estimatedQuantity: estimatedQuantity ?? this.estimatedQuantity,
      cookingStyle: cookingStyle ?? this.cookingStyle,
      confirmed: confirmed ?? this.confirmed,
      x: x ?? this.x,
      y: y ?? this.y,
    );
  }

  factory DetectedItem.fromJson(Map<String, dynamic> json) => DetectedItem(
        name: json['name'] as String? ?? 'Unknown',
        estimatedQuantity: json['estimated_quantity'] as String? ?? '1 serving',
        x: (json['x'] as num?)?.toDouble().clamp(0.05, 0.95) ?? 0.5,
        y: (json['y'] as num?)?.toDouble().clamp(0.05, 0.95) ?? 0.5,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'estimated_quantity': estimatedQuantity,
        'cooking_style': cookingStyle,
        'x': x,
        'y': y,
      };
}

class DetectionResult {
  final List<DetectedItem> items;
  final List<String> suggestedLabels;
  final bool isFromApi;

  DetectionResult({
    required this.items,
    required this.suggestedLabels,
    this.isFromApi = false,
  });

  DetectionResult copyWithItem(int index, DetectedItem item) {
    final newItems = List<DetectedItem>.from(items);
    newItems[index] = item;
    return DetectionResult(
      items: newItems,
      suggestedLabels: suggestedLabels,
      isFromApi: isFromApi,
    );
  }
}
