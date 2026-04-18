import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_config.dart';
import '../features/history/data/models/meal_model.dart';
import 'indian_food_db.dart';
import 'quantity_parser.dart';

/// Low-level exception from the remote inference call.
/// Internal-only — never shown to users directly. The UI layer maps this
/// to a neutral, vendor-free [MealAnalysisException.userMessage].
class GeminiApiException implements Exception {
  final int statusCode;
  final String message;
  GeminiApiException(this.statusCode, this.message);

  @override
  String toString() => 'GeminiApiException($statusCode): $message';

  bool get isQuotaExhausted => statusCode == 429;
  bool get isNotFound => statusCode == 404;
  bool get isAuthError => statusCode == 401 || statusCode == 403;
  bool get isServerError => statusCode >= 500 && statusCode < 600;
  bool get isTransient => isQuotaExhausted || isServerError || statusCode == 0;
}

/// Reason code for why meal analysis failed. Used by the UI to show a
/// specific user-friendly message without leaking any vendor or status codes.
enum AnalysisFailureReason {
  network, // no connectivity / DNS / socket
  timeout, // request took too long
  rateLimited, // too many requests right now
  serviceDown, // upstream 5xx
  invalidResponse, // upstream returned something we couldn't parse
  unknown,
}

/// Exception raised by [GeminiService.analyzeThaliImage] when the meal could
/// not be analyzed reliably. Callers MUST surface [userMessage] to end users,
/// never [toString] — toString may contain internal diagnostic detail.
class MealAnalysisException implements Exception {
  final AnalysisFailureReason reason;
  final String _diagnostic;

  MealAnalysisException(this.reason, [this._diagnostic = '']);

  /// Neutral, vendor-free message safe to display to users.
  String get userMessage {
    switch (reason) {
      case AnalysisFailureReason.network:
        return 'Check your internet connection and try again.';
      case AnalysisFailureReason.timeout:
        return 'The analysis took too long to respond. Please try again.';
      case AnalysisFailureReason.rateLimited:
        return "We're getting a lot of requests right now. Please try again in a minute.";
      case AnalysisFailureReason.serviceDown:
        return 'Our analysis service is temporarily unavailable. Please try again shortly.';
      case AnalysisFailureReason.invalidResponse:
        return "We couldn't read the analysis result. Please try again.";
      case AnalysisFailureReason.unknown:
        return "Couldn't analyze your meal right now. Please try again.";
    }
  }

  @override
  String toString() =>
      'MealAnalysisException(${reason.name})${_diagnostic.isEmpty ? '' : ': $_diagnostic'}';
}

class GeminiService {
  static String get _apiKey => ApiConfig.geminiApiKey;
  static String get _model => ApiConfig.geminiModel;

  // Retry policy
  static const int _maxAttempts = 3;
  static const Duration _perAttemptTimeout = Duration(seconds: 25);
  // Backoff schedule between attempts when the server gives no Retry-After hint.
  static const List<Duration> _backoffs = [
    Duration(seconds: 1),
    Duration(seconds: 3),
  ];
  // Cap on how long we'll respect a server-specified Retry-After so users
  // don't sit on a loading screen for 30+ seconds.
  static const Duration _maxRetryAfter = Duration(seconds: 8);

  String _buildUrl(String model) =>
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$_apiKey';

  /// Step 1: Detect food items from the photo.
  /// Throws [MealAnalysisException] on hard failure. The UI layer may choose
  /// to let the user proceed with manual item entry on detection failure.
  Future<DetectionResult> detectFoodItems(String imagePath) async {
    final imageBytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(imageBytes);

    const prompt = '''
You are an expert Indian food nutritionist. Carefully analyze this photo and detect EVERY distinct food item visible.

For each item, estimate its CENTER position in the image as x,y fractions where:
- x: 0.0 = left edge, 0.5 = center, 1.0 = right edge
- y: 0.0 = top edge, 0.5 = center, 1.0 = bottom edge

Also classify each item into ONE of these categories:
- "main_dish"      → curries, dals, sabzis, gravies, meat dishes, paneer dishes, idli, dosa, upma, poha, eggs
- "bread"          → roti, chapati, naan, paratha, puri, bhatura, kulcha, dosa (as bread), thepla
- "rice"           → steamed rice, biryani, pulao, khichdi, fried rice
- "dairy"          → raita, curd, yogurt, lassi, buttermilk, paneer (standalone)
- "salad_side"     → salads, kachumber, slaws, cut vegetables, sprouts
- "condiment"      → chutney, pickle, achar, papad, sauce, murabba, jam
- "beverage"       → tea, coffee, juice, water, lassi (as drink)
- "dessert"        → mithai, kheer, halwa, ice cream, gulab jamun
- "snack"          → chakli, murukku, namkeen, bhujia, chips, farsan

For each item also output a STRUCTURED quantity using the most natural unit for that specific food:
- unit: ONE of "piece", "bowl", "plate", "serving", "cup", "tbsp", "tsp", "ml", "gram"
  • pieces → discrete countable items (idli, vada, roti, samosa, pakora, tikki, momo, uttapam, puri, paratha, dosa, dhokla, gulab jamun, kachori, kebab…)
  • bowl  → liquid/semi-solid main dishes (dal, sambar, curry, sabzi, raita, kheer served in a bowl)
  • plate → rice/biryani/pulao portions or thali-size servings
  • serving → generic portions when no natural unit fits
  • cup  → tea/coffee/lassi/buttermilk or measured cup of rice
  • tbsp / tsp → condiments, pickles, chutneys, ghee, honey
  • ml   → beverages where a volume is obvious (200ml, 300ml)
  • gram → weighed items (less common; use only when natural)
- count: numeric quantity in that unit (e.g. 3 for "3 pieces", 1 for "1 bowl", 0.5 for "½ plate")
- typical_unit_grams: approximate grams of ONE of this unit for this food (e.g. idli piece ≈ 40g; roti ≈ 35g; 1 bowl dal ≈ 150g; 1 cup tea ≈ 200g). Best-effort integer.

IMPORTANT counting rules:
- For discrete countable items, COUNT ONLY FULLY VISIBLE PIECES. Do not guess occluded or partially-hidden pieces. Under-count is preferred over over-count.
- For plates/bowls, estimate the portion size relative to a standard adult serving.

Return ONLY this exact JSON format:

{
  "items": [
    {"name": "Idli", "category": "main_dish", "unit": "piece", "count": 2, "typical_unit_grams": 40, "estimated_quantity": "2 pieces", "x": 0.5, "y": 0.6},
    {"name": "Sambar", "category": "main_dish", "unit": "bowl", "count": 1, "typical_unit_grams": 150, "estimated_quantity": "1 bowl", "x": 0.3, "y": 0.3},
    {"name": "Coconut Chutney", "category": "condiment", "unit": "tbsp", "count": 2, "typical_unit_grams": 15, "estimated_quantity": "2 tbsp", "x": 0.7, "y": 0.2}
  ],
  "suggested_labels": ["Idli", "Sambar", "Coconut Chutney"]
}

Rules:
- Detect EVERY distinct food item. Don't miss anything — check bowls, sides, bread, rice, pickles, chutneys, papad, salad, etc.
- NEVER duplicate items. If there are 3 rotis, list once as "Roti" with unit="piece", count=3, estimated_quantity="3 pieces".
- Use specific Indian dish names (e.g. "Bhindi Masala" not "Vegetable Curry").
- x,y MUST accurately point to the CENTER of each food item in the photo. Be precise.
- Always include: name, category, unit, count, typical_unit_grams, estimated_quantity, x, y.
- Return ONLY valid JSON, no markdown, no extra text.''';

    final response = await _callWithRetry(prompt, base64Image);
    List<DetectedItem> items;
    List<String> labels;
    try {
      final parsed = _extractJson(response);
      items = (parsed['items'] as List?)
              ?.map((e) => DetectedItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      labels = (parsed['suggested_labels'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          items.map((e) => e.name).toList();
    } catch (e) {
      debugPrint('[Detection] Failed to parse response: $e');
      throw MealAnalysisException(
          AnalysisFailureReason.invalidResponse, e.toString());
    }

    // Best-effort second pass, GATED by [VerificationGate]. Running the
    // verification on a structurally complete plate (e.g. a full thali with
    // mains + bread/rice + a condiment) historically added more hallucinated
    // items than real ones. So we only fire it when the first-pass result
    // looks structurally sparse — the classic miss pattern is "several mains
    // but zero small sides". If the gate says skip, we honor the first pass.
    List<DetectedItem> missed = const [];
    if (VerificationGate.shouldVerify(items)) {
      missed = await _verifyAndExtendDetection(
        base64Image: base64Image,
        existing: items,
      );
      if (missed.isNotEmpty) {
        debugPrint(
            '[Verify] added ${missed.length} previously missed item(s): '
            '${missed.map((i) => i.name).join(", ")}');
      }
    } else {
      debugPrint(
          '[Verify] skipped — first-pass plate looks structurally complete '
          '(${items.length} items across ${items.map((i) => i.category).toSet().length} categories)');
    }

    return DetectionResult(
      items: DetectionMerge.dedupeByName(items, missed),
      suggestedLabels: DetectionMerge.dedupeLabels(labels, missed),
      isFromApi: true,
    );
  }

  /// Best-effort verification pass. Single-shot (no retry) with a short
  /// timeout — a failure here MUST NOT block the user, who already has
  /// a valid first-pass result.
  Future<List<DetectedItem>> _verifyAndExtendDetection({
    required String base64Image,
    required List<DetectedItem> existing,
  }) async {
    if (existing.isEmpty) return const [];

    try {
      final prompt = _buildVerificationPrompt(existing);
      // Wrap in a short timeout — verification isn't worth >10s of user wait.
      final text = await _callOnce(prompt, base64Image, _model)
          .timeout(const Duration(seconds: 12));
      if (text == null || text.isEmpty) return const [];

      final parsed = _extractJson(text);
      final raw = parsed['missed_items'] as List?;
      if (raw == null || raw.isEmpty) return const [];

      // Client-side belt: drop any addition that didn't come back with a
      // non-empty "visual_evidence" string. An item the model can't describe
      // is an item the model didn't actually see.
      final additions = <DetectedItem>[];
      for (final e in raw) {
        if (e is! Map<String, dynamic>) continue;
        final evidence =
            (e['visual_evidence'] as String? ?? '').trim();
        if (evidence.isEmpty) {
          debugPrint(
              '[Verify] rejected "${e['name']}" — no visual_evidence provided');
          continue;
        }
        additions.add(DetectedItem.fromJson(e));
      }
      return additions;
    } catch (e) {
      debugPrint('[Verify] skipped (best-effort): $e');
      return const [];
    }
  }

  String _buildVerificationPrompt(List<DetectedItem> existing) {
    final listed = existing
        .map((i) => '- ${i.name} (${i.estimatedQuantity})')
        .join('\n');

    // Evidence-bound verification prompt. The previous version listed
    // example items (papad, pickle, lemon wedge, red onion) which the model
    // treated as a checklist and added them regardless of visibility —
    // classic priming failure. The new contract forbids adding an item
    // unless the model can describe the specific visual cue that proves
    // it exists, and treats an empty array as a legitimate success.
    return '''
You previously analyzed this Indian food photo and listed these items:

$listed

Re-examine the photo. Your job is NOT to guess what usually comes with this kind of meal — it is to check whether any DISTINCT food item is visually present in the photo that is missing from the list above.

For EACH item you consider adding, you must be able to point to a specific visible cue — its color, shape, container, texture, or location in the frame. If you cannot describe a concrete visual cue, the item does NOT exist in the photo and you must NOT add it.

Return ONLY a JSON object in this exact format:

{
  "missed_items": [
    {"name": "<food name>", "category": "<category>", "unit": "<unit>", "count": <n>, "typical_unit_grams": <g>, "estimated_quantity": "<qty>", "x": <0..1>, "y": <0..1>, "visual_evidence": "<one short sentence describing the exact visual cue you see>"}
  ]
}

STRICT RULES:
- The correct answer when nothing is missed is {"missed_items": []}. Returning an empty array is a SUCCESS, not a failure.
- Do NOT add items just because they are commonly served with this type of meal (rice, raita, onion, lemon, papad, pickle, etc.). These hallucinations are the #1 failure mode — only include them if you can genuinely see them in the photo.
- Do NOT re-add an item you already listed, even under a slightly different name.
- Every item you add MUST include a non-empty "visual_evidence" string naming the specific cue you observed. Items without concrete visual evidence will be rejected.
- Use the same categories (main_dish, bread, rice, dairy, salad_side, condiment, beverage, dessert, snack) and units (piece, bowl, plate, serving, cup, tbsp, tsp, ml, gram) as before.
- Always include: name, category, unit, count, typical_unit_grams, estimated_quantity, x, y, visual_evidence.
- Return ONLY valid JSON, no markdown, no extra text.''';
  }

  /// Step 2: Get full nutritional breakdown based on user-confirmed detected items.
  ///
  /// Contract: Returns a [MealAnalysis] ONLY when the upstream model responds
  /// successfully with valid nutrition JSON. Never returns fabricated or
  /// silently-estimated values. On failure, throws [MealAnalysisException]
  /// so the UI can offer retry / manual entry / discard — never a wrong number.
  Future<MealAnalysis> analyzeThaliImage({
    required String imagePath,
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

${detectedContext}For each food item, provide precise nutritional estimates considering the cooking style and quantity specified.
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
- Use the EXACT quantities from the detected items list above. For countable items
  (e.g. "4 pieces" of Idli, "3 pieces" of Roti), calculate total calories for ALL pieces combined.
- Be realistic with typical Indian food portions for the specified cooking style.
- Use IFCT 2017 / NIN calorie values for Indian food preparations.
- healthScore: integer 1-10 (10 = very healthy, balanced meal).
- healthTip: one practical tip to improve this meal's nutrition.
- cooking_style: preserve the user-confirmed cooking style for each item.
''';

    final response = await _callWithRetry(prompt, base64Image);
    try {
      final parsed = _extractJson(response);
      return _parseNutritionResponse(parsed, mealId, imagePath);
    } catch (e) {
      debugPrint('[Analysis] Failed to parse response: $e');
      throw MealAnalysisException(
          AnalysisFailureReason.invalidResponse, e.toString());
    }
  }

  /// Calls the remote model with exponential-ish backoff. Single model (no
  /// fake same-vendor fallback — that's not real redundancy). Throws a
  /// [MealAnalysisException] with a specific [AnalysisFailureReason] on
  /// final failure so the UI can show a targeted message.
  Future<String> _callWithRetry(String prompt, String base64Image) async {
    AnalysisFailureReason lastReason = AnalysisFailureReason.unknown;
    String lastDiag = '';

    for (int attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        final result = await _callOnce(prompt, base64Image, _model);
        if (result != null && result.isNotEmpty) return result;
        lastReason = AnalysisFailureReason.invalidResponse;
        lastDiag = 'empty response';
      } on TimeoutException catch (e) {
        debugPrint('[AI] attempt ${attempt + 1} timeout: $e');
        lastReason = AnalysisFailureReason.timeout;
        lastDiag = e.toString();
      } on SocketException catch (e) {
        debugPrint('[AI] attempt ${attempt + 1} network: $e');
        lastReason = AnalysisFailureReason.network;
        lastDiag = e.toString();
      } on GeminiApiException catch (e) {
        debugPrint('[AI] attempt ${attempt + 1}: ${e.statusCode} ${e.message}');
        lastDiag = e.message;

        if (e.isAuthError || e.isNotFound) {
          // Won't get better on retry.
          lastReason = AnalysisFailureReason.serviceDown;
          break;
        }
        if (e.isQuotaExhausted) {
          lastReason = AnalysisFailureReason.rateLimited;
        } else if (e.isServerError) {
          lastReason = AnalysisFailureReason.serviceDown;
        } else {
          lastReason = AnalysisFailureReason.unknown;
        }
        if (!e.isTransient) break;
      } catch (e) {
        debugPrint('[AI] attempt ${attempt + 1} unexpected: $e');
        lastReason = AnalysisFailureReason.unknown;
        lastDiag = e.toString();
      }

      // Backoff if we have another attempt coming.
      if (attempt < _maxAttempts - 1) {
        final wait = attempt < _backoffs.length
            ? _backoffs[attempt]
            : _backoffs.last;
        await Future<void>.delayed(wait);
      }
    }

    throw MealAnalysisException(lastReason, lastDiag);
  }

  /// Single remote request. Returns the raw text on 2xx, null if the payload
  /// is shaped unexpectedly but still 2xx, or throws [GeminiApiException]
  /// for non-2xx responses.
  Future<String?> _callOnce(String prompt, String base64Image, String model) async {
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
        .timeout(_perAttemptTimeout);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text =
          data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      return text;
    }

    String errorMsg = 'HTTP ${response.statusCode}';
    try {
      final errorData = jsonDecode(response.body);
      errorMsg = errorData['error']?['message'] as String? ?? errorMsg;
    } catch (_) {}

    // Respect server Retry-After for 429/503, capped to avoid UX deadlock.
    if (response.statusCode == 429 || response.statusCode == 503) {
      final retryAfter = _parseRetryAfter(response.headers['retry-after']) ??
          _parseRetryDelayFromMessage(errorMsg);
      if (retryAfter != null) {
        final capped =
            retryAfter > _maxRetryAfter ? _maxRetryAfter : retryAfter;
        await Future<void>.delayed(capped);
      }
    }

    throw GeminiApiException(response.statusCode, errorMsg);
  }

  Duration? _parseRetryAfter(String? header) {
    if (header == null) return null;
    final secs = int.tryParse(header.trim());
    if (secs != null) return Duration(seconds: secs.clamp(0, 60));
    return null;
  }

  Duration? _parseRetryDelayFromMessage(String message) {
    final match = RegExp(r'retry in (\d+)').firstMatch(message.toLowerCase());
    if (match != null) {
      final secs = int.tryParse(match.group(1)!) ?? 5;
      return Duration(seconds: secs.clamp(2, 30));
    }
    return null;
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
    String mealId,
    String imagePath,
  ) {
    final rawItemsList = data['items'] as List?;
    if (rawItemsList == null || rawItemsList.isEmpty) {
      throw MealAnalysisException(
          AnalysisFailureReason.invalidResponse, 'no items in response');
    }

    final rawItems = rawItemsList
        .map((e) => FoodItem.fromJson(e as Map<String, dynamic>))
        .toList();

    // Enrichment, NOT fallback: the model already successfully identified
    // the item — we only top up macros when it returned 0 for a known food.
    // This stays within the "the AI succeeded" path. If the AI fails entirely,
    // we never reach this method.
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
}

/// A single food item detected (or added) on the meal-confirmation screen.
///
/// Carries both a human-readable [estimatedQuantity] (e.g. "3 pieces") AND
/// a structured ([count], [unit]) pair so the edit sheet can offer the right
/// control (piece stepper vs bowl chips vs portion multiplier) without any
/// hardcoded food-name lists.
///
/// Unit resolution order (all backward-compatible):
///   1. Use the structured `unit`/`count` fields when present in upstream JSON.
///   2. Otherwise fall back to [QuantityParser.parse] over [estimatedQuantity].
///   3. Unknown units become [QuantityUnit.multiplier] and the UI shows
///      the universal 0.5×–3× portion multiplier.
class DetectedItem {
  final String name;
  final String estimatedQuantity;
  final String cookingStyle;
  final bool confirmed;
  final double x; // 0.0 (left) to 1.0 (right) position in image
  final double y; // 0.0 (top) to 1.0 (bottom) position in image

  /// Raw category string (e.g. "main_dish", "condiment", "bread").
  final String category;

  /// Numeric quantity in [unit]s (e.g. 3 for "3 pieces", 0.5 for "½ plate").
  final double count;

  /// Canonical unit. Derived from the structured upstream field when present,
  /// else parsed from [estimatedQuantity].
  final QuantityUnit unit;

  /// Approximate grams for ONE of this unit (e.g. 40 for a single idli).
  /// Used by the calorie engine for portion scaling. May be 0 when unknown.
  final double typicalUnitGrams;

  DetectedItem({
    required this.name,
    required this.estimatedQuantity,
    this.cookingStyle = 'Home',
    this.confirmed = false,
    this.x = 0.5,
    this.y = 0.5,
    this.category = 'main_dish',
    this.count = 1,
    this.unit = QuantityUnit.serving,
    this.typicalUnitGrams = 0,
  });

  DetectedItem copyWith({
    String? name,
    String? estimatedQuantity,
    String? cookingStyle,
    bool? confirmed,
    double? x,
    double? y,
    String? category,
    double? count,
    QuantityUnit? unit,
    double? typicalUnitGrams,
  }) {
    return DetectedItem(
      name: name ?? this.name,
      estimatedQuantity: estimatedQuantity ?? this.estimatedQuantity,
      cookingStyle: cookingStyle ?? this.cookingStyle,
      confirmed: confirmed ?? this.confirmed,
      x: x ?? this.x,
      y: y ?? this.y,
      category: category ?? this.category,
      count: count ?? this.count,
      unit: unit ?? this.unit,
      typicalUnitGrams: typicalUnitGrams ?? this.typicalUnitGrams,
    );
  }

  /// Parses upstream JSON. When `unit` is missing we fall back to
  /// [QuantityParser.parse] so older payloads still work.
  factory DetectedItem.fromJson(Map<String, dynamic> json) {
    final qty = json['estimated_quantity'] as String? ?? '1 serving';

    final rawUnit = json['unit'] as String?;
    var unit = QuantityParser.unitFromString(rawUnit);

    final rawCount = (json['count'] as num?)?.toDouble();

    if (unit == null) {
      final parsed = QuantityParser.parse(qty);
      unit = parsed.unit;
    }

    final count = rawCount ?? QuantityParser.parse(qty).count;

    return DetectedItem(
      name: json['name'] as String? ?? 'Unknown',
      estimatedQuantity: qty,
      x: (json['x'] as num?)?.toDouble().clamp(0.05, 0.95) ?? 0.5,
      y: (json['y'] as num?)?.toDouble().clamp(0.05, 0.95) ?? 0.5,
      category: json['category'] as String? ?? 'main_dish',
      count: count,
      unit: unit,
      typicalUnitGrams:
          (json['typical_unit_grams'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'estimated_quantity': estimatedQuantity,
        'cooking_style': cookingStyle,
        'category': category,
        'count': count,
        'unit': unit.name,
        'typical_unit_grams': typicalUnitGrams,
        'x': x,
        'y': y,
      };

  /// Whether this item ever needs cooking-style selection.
  /// Condiments, beverages and desserts have negligible style-based calorie variation.
  bool get needsCookingStyle =>
      category != 'condiment' &&
      category != 'beverage' &&
      category != 'dessert' &&
      category != 'snack';

  /// True when the item is discretely countable (idli, roti, vada…).
  /// Drives whether the edit sheet shows a `[−] N [+]` stepper.
  bool get isCountable => unit == QuantityUnit.piece;
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

/// Pure gate that decides whether the expensive second-pass verification
/// should run at all. History: without gating, the verification pass added
/// more hallucinated items (Steamed Rice, Sliced Red Onion on plates that
/// had neither) than it rescued, because "commonly missed" prompting primes
/// the model to invent likely-companions. The safest default is therefore
/// to TRUST the first pass and only re-ask the model when the first pass
/// looks structurally sparse — i.e. the classic "caught the mains but
/// missed the small sides" pattern.
///
/// A plate is considered complete (verification SKIPPED) when any of:
///   • It already has ≥ [_denseTotal] items — diminishing returns vs. risk.
///   • It has a main dish AND (bread OR rice) AND at least one small-side
///     class (condiment/salad_side/dairy) — structurally diverse.
///   • It has ≥ [_manyMains] main dishes AND (bread OR rice) — full thali
///     already recognised.
///
/// Otherwise we FIRE verification — most commonly when the plate has mains
/// but no condiment/salad/dairy yet, where a papad, chutney bowl, lemon
/// wedge, or garnish is most often the genuine miss.
class VerificationGate {
  VerificationGate._();

  /// Total-item threshold above which we skip the second pass regardless
  /// of category mix. Dense plates rarely benefit.
  static const int _denseTotal = 8;

  /// Main-dish count at which we consider the plate a "full thali" and
  /// skip verification if bread/rice is also present.
  static const int _manyMains = 4;

  /// Returns true when the second-pass verification SHOULD run for this
  /// first-pass result. Pure, deterministic, and test-friendly.
  static bool shouldVerify(List<DetectedItem> firstPass) {
    if (firstPass.isEmpty) return false;
    if (firstPass.length >= _denseTotal) return false;

    final categories =
        firstPass.map((i) => i.category.trim().toLowerCase()).toSet();
    final hasMain = categories.contains('main_dish');
    final hasBread = categories.contains('bread');
    final hasRice = categories.contains('rice');
    final hasCondiment = categories.contains('condiment');
    final hasSide = categories.contains('salad_side');
    final hasDairy = categories.contains('dairy');
    final hasSmallSide = hasCondiment || hasSide || hasDairy;

    if (hasMain && (hasBread || hasRice) && hasSmallSide) return false;

    final mainCount = firstPass
        .where((i) => i.category.trim().toLowerCase() == 'main_dish')
        .length;
    if (mainCount >= _manyMains && (hasBread || hasRice)) return false;

    return true;
  }
}

/// Pure helpers for merging first-pass and verification-pass detection
/// results, extracted so the dedupe logic can be tested independently of
/// any HTTP call in [GeminiService.detectFoodItems].
///
/// Contract: the first-pass list is the source of truth for order and for
/// tie-breaking. Verification-pass items are only appended when their
/// trimmed, case-insensitive [DetectedItem.name] isn't already present.
class DetectionMerge {
  DetectionMerge._();

  static String _key(String n) => n.trim().toLowerCase();

  /// Appends [additions] to [original], dropping any addition whose name
  /// (case-insensitive, trimmed) already appears in [original]. Preserves
  /// original order, then appends net-new items in their given order.
  static List<DetectedItem> dedupeByName(
    List<DetectedItem> original,
    List<DetectedItem> additions,
  ) {
    if (additions.isEmpty) return List.of(original);

    final seen = original.map((i) => _key(i.name)).toSet();
    final merged = List<DetectedItem>.from(original);

    for (final item in additions) {
      final k = _key(item.name);
      if (k.isEmpty || seen.contains(k)) continue;
      seen.add(k);
      merged.add(item);
    }

    return merged;
  }

  /// Same dedupe contract for the suggested-labels list (used by the
  /// manual "+ Add Item" sheet). Keeps original labels, then appends
  /// names from additions that aren't already present.
  static List<String> dedupeLabels(
    List<String> original,
    List<DetectedItem> additions,
  ) {
    if (additions.isEmpty) return List.of(original);

    final seen = original.map(_key).toSet();
    final merged = List<String>.from(original);
    for (final item in additions) {
      final k = _key(item.name);
      if (k.isEmpty || seen.contains(k)) continue;
      seen.add(k);
      merged.add(item.name);
    }
    return merged;
  }
}
